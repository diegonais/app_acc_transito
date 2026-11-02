import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/report_date_bounds.dart';
import '../repositories/report_repository_contract.dart';
import '../../features/auth/data/online_auth_repository.dart';
import '../../features/auth/domain/authenticated_user.dart';
import '../../services/qr/institutional_qr_service.dart';
import '../../services/media/evidence_photo.dart';
import 'online_file_service.dart';
import 'online_report_operations.dart';
import 'remote_gateway.dart';

class _PendingReport {
  _PendingReport(
      this.uid, this.operation, this.payload, this.fingerprint, this.files);
  final String uid;
  final String operation;
  final Map<String, dynamic> payload;
  final String fingerprint;
  Future<FinalizedReport>? inFlight;
  bool blocked = false;
  final List<PendingOnlineFile> files;
}

class OnlineReportRepository
    implements ReportRepositoryContract, OnlineReportOperations {
  OnlineReportRepository(this.gateway,
      {this.clock = DateTime.now,
      String Function()? operationId,
      OnlineFileService? fileService})
      : _operationId = operationId ?? const Uuid().v4,
        files = fileService ?? OnlineFileService(gateway);
  final RemoteGateway gateway;
  final String Function() _operationId;
  final OnlineFileService files;
  final Map<String, (String, PendingOnlineFile)> _pdfs = {};
  @override
  final DateTime Function() clock;
  final Map<String, _PendingReport> _pending = {};

  @override
  bool get hasPendingFinalization => _pending.containsKey(gateway.userId);
  @override
  Future<void> beginReport() async {
    if (hasPendingFinalization) {
      throw const OnlineException(
          'Existe una finalización sin confirmar. Recupérela antes de crear otro informe.');
    }
  }

  Future<AuthenticatedUser> _actor() async {
    final user = await OnlineAuthRepository(gateway).restoreSession();
    if (user == null)
      throw const OnlineException('La sesión terminó. Ingrese nuevamente.');
    return user;
  }

  @override
  Future<FinalizedReport> finalizeReport(FinalizeReportInput input,
      {DateTime? now,
      PersistPhotosForCase? persistPhotosForCase,
      CleanupPhotos? cleanupPersistedPhotos}) async {
    final actor = await _actor();
    if (!actor.isPolice || actor.requiredPoliceId != input.idPolicia) {
      throw const OnlineException(
          'Solo el policía autenticado puede finalizar su informe.');
    }
    if (input.fotografias.length > 12 || input.rutaPdf != null) {
      throw const OnlineException(
          'Se admiten hasta 12 fotografías y un croquis. El PDF se genera después de finalizar.');
    }
    if (input.fotografias
        .any((p) => p.descripcion?.trim().isNotEmpty == true)) {
      throw const OnlineException(
          'El contrato remoto no conserva descripciones de fotografías. Retire la descripción antes de finalizar; no se omitirá silenciosamente.');
    }
    final payload = reportPayload(input);
    final fingerprint = jsonEncode([
      payload,
      input.rutaCroquis,
      input.fotografias.map((p) => [p.ruta, p.tipo.databaseValue]).toList()
    ]);
    final uid = gateway.userId!;
    var pending = _pending[uid];
    if (pending != null && pending.fingerprint != fingerprint) {
      throw const OnlineException(
          'Hay una finalización sin confirmar con otro contenido. Recupere esa operación antes de cambiar los datos.');
    }
    if (pending == null) {
      final attachments = [
        for (final p in input.fotografias)
          PendingOnlineFile(
              localPath: p.ruta,
              kind: 'FOTOGRAFIA',
              type: p.tipo.databaseValue),
        if (input.rutaCroquis != null)
          PendingOnlineFile(localPath: input.rutaCroquis!, kind: 'CROQUIS'),
      ];
      final frozen = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      if (attachments.isNotEmpty)
        frozen['archivos'] = attachments.map((f) => f.reservation).toList();
      pending = _pending[uid] =
          _PendingReport(uid, _operationId(), frozen, fingerprint, attachments);
    }
    return _run(pending);
  }

  @override
  Future<FinalizedReport> resumeFinalization() async {
    final pending = _pending[gateway.userId];
    if (pending == null)
      throw const OnlineException(
          'No hay una operación pendiente en esta sesión.');
    return _run(pending);
  }

  Future<FinalizedReport> _run(_PendingReport pending) {
    return pending.inFlight ??=
        _replay(pending).whenComplete(() => pending.inFlight = null);
  }

  Future<FinalizedReport> _replay(_PendingReport pending) async {
    if (pending.blocked) {
      throw const OnlineException(
          'La operación requiere revisión. No se reintentará el error 546. Conserve esta sesión.');
    }
    // Toda carga/verificación termina antes de la transacción SQL. Un error
    // conserva la misma intención y sus reservas; jamás descarta adjuntos.
    try {
      await files.prepare(pending.uid, pending.operation, pending.files);
    } catch (_) {
      // Validaciones de archivos ANTES de cualquier reserva permiten corregir
      // el formulario. Una respuesta perdida de reserva conserva su intención.
      if (!pending.files.any((f) => f.reservationAttempted))
        _pending.remove(pending.uid);
      rethrow;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      if (gateway.userId != pending.uid)
        throw const OnlineException(
            'Cambió la sesión. Ingrese con el autor para recuperar la operación.');
      try {
        final r = await gateway.rpc('finalizar_informe', {
          'operation_id': pending.operation,
          // Cada intento recibe una copia del JSON congelado, nunca del formulario.
          'payload': jsonDecode(jsonEncode(pending.payload)),
        }) as Map;
        final result = FinalizedReport(
            idInforme: r['id_informe'],
            gestion: r['gestion'],
            correlativo: r['correlativo'],
            numeroCaso: r['numero_caso']);
        _pending.remove(pending.uid);
        return result;
      } catch (error) {
        if (!isTransientOnlineError(error)) {
          // Errores deterministas no disparan replay automático.
          if (error is PostgrestException && error.code == '546') {
            pending.blocked = true;
            throw const OnlineException(
                'El servidor respondió 546. No se reintentará la operación; requiere revisión.');
          }
          if (error is PostgrestException &&
              (error.code?.startsWith('22') == true ||
                  const [
                    '42501',
                    '23514',
                    'PT409',
                    'PT422',
                    '401',
                    '403',
                    '400',
                    '409',
                    '422'
                  ].contains(error.code))) {
            _pending.remove(pending.uid);
          }
          throw const OnlineException(
              'El servidor no confirmó la finalización. Revise permisos, datos y conexión. Si la operación sigue pendiente, recupérela sin crear otro informe.');
        }
        if (attempt == 1) {
          throw const OnlineException(
              'No se pudo confirmar si el informe se guardó. No cree otro: use Recuperar finalización pendiente con la misma sesión. No cierre la aplicación.');
        }
      }
    }
    throw StateError('Replay agotado');
  }

  Future<List<ReportRecord>> _reports(
      {int? police,
      ReportQueryFilter filter = const ReportQueryFilter()}) async {
    final rows = await gateway.select('informes', equals: {
      'estado': 1,
      if (police ?? filter.idPolicia case final id?) 'id_policia': id
    });
    final reports = rows.map(mapReport).where((r) {
      final date = r.fechaHoraHecho;
      return (filter.from == null ||
              (date != null && !date.isBefore(filter.from!))) &&
          (filter.to == null || (date != null && date.isBefore(filter.to!)));
    }).toList();
    reports.sort((a, b) => b.idInforme.compareTo(a.idInforme));
    return reports;
  }

  @override
  Future<List<ReportRecord>> queryActiveReportsForAdmin(
      {ReportQueryFilter filter = const ReportQueryFilter()}) async {
    if (!(await _actor()).isAdmin)
      throw const OnlineException('Consulta reservada a ADMIN.');
    return _reports(filter: filter);
  }

  @override
  Future<List<ReportRecord>> queryActiveReportsForPolice(
      {required int idPolicia,
      ReportQueryFilter filter = const ReportQueryFilter()}) async {
    final actor = await _actor();
    if (!actor.isPolice || actor.requiredPoliceId != idPolicia)
      throw const OnlineException('Solo puede consultar sus informes.');
    return _reports(police: idPolicia, filter: filter);
  }

  @override
  Future<ReportDateBounds> loadDateBounds({int? idPolicia}) async {
    final rows = await _reports(police: idPolicia);
    final dates = rows
        .map((r) => r.fechaHoraHecho)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return ReportDateBounds(
        today: clock(), earliestReportDate: dates.firstOrNull);
  }

  @override
  Future<ReportRecord?> findActiveReportDetail(int idInforme) async {
    // RLS impone el acceso también si se conoce un id ajeno.
    final rows = await gateway
        .select('informes', equals: {'id_informe': idInforme, 'estado': 1});
    if (rows.isEmpty) return null;
    var report = mapReport(rows.single);
    final drivers =
        await gateway.select('conductores', equals: {'id_informe': idInforme});
    final vehicles =
        await gateway.select('vehiculos', equals: {'id_informe': idInforme});
    final persons = await gateway
        .select('personas_involucradas', equals: {'id_informe': idInforme});
    final files = await gateway
        .select('archivos_informe', equals: {'id_informe': idInforme});
    final photos =
        await gateway.select('fotografias', equals: {'id_informe': idInforme});
    final uid = gateway.userId;
    if (uid == null) throw const OnlineException('La sesión terminó.');
    final photoRecords = <PhotoRecord>[];
    String? sketch;
    String? pdf;
    for (final descriptor in files) {
      final local = await this.files.readFile(uid, descriptor);
      if (descriptor['clase'] == 'CROQUIS') sketch = local;
      if (descriptor['clase'] == 'PDF') pdf = local;
      if (descriptor['clase'] == 'FOTOGRAFIA') {
        final photo = photos
            .singleWhere((p) => p['id_archivo'] == descriptor['id_archivo']);
        photoRecords.add(PhotoRecord(
            idFotografia: photo['id_fotografia'],
            ruta: local,
            tipo: EvidencePhotoCategory.fromDatabase(photo['tipo']),
            descripcion: photo['descripcion']));
      }
    }
    report = report.copyWith(
        rutaCroquis: sketch,
        rutaPdf: pdf,
        fotografias: photoRecords,
        conductores: drivers.map(mapDriver).toList(),
        vehiculos: vehicles.map(mapVehicle).toList(),
        personas: persons.map(mapPerson).toList());
    return report;
  }

  @override
  Future<ReportRecord?> findActiveReportDetailForPolice(
      {required int idInforme, required int idPolicia}) async {
    final actor = await _actor();
    if (!actor.isPolice || actor.requiredPoliceId != idPolicia)
      throw const OnlineException('No tiene permiso para ese informe.');
    final report = await findActiveReportDetail(idInforme);
    return report?.idPolicia == idPolicia ? report : null;
  }

  @override
  Future<InstitutionalQrPolice> findReportOwnerQrIdentity(
          int idPolicia) async =>
      throw const OnlineException(
          'En línea se requiere la instantánea del informe.');
  @override
  Future<List<PoliceReportCount>> listPoliceReportCounts() async {
    final reports = await _reports();
    final police = await gateway.select('policias', equals: {'estado': 1});
    final users = await gateway.select('usuarios', equals: {'estado': 1});
    return police
        .where((p) => users.any((u) => u['id_usuario'] == p['id_usuario']))
        .map((p) => PoliceReportCount(
            idPolicia: p['id_policia'],
            grado: p['grado'],
            nombres: p['nombres'],
            apellidos: p['apellidos'],
            numeroPlaca: p['numero_placa'],
            total: reports.where((r) => r.idPolicia == p['id_policia']).length))
        .toList();
  }

  Future<DashboardStats> _dashboard(DateTime reference, DateTime? selected,
      {int? police}) async {
    final reports = await _reports(police: police);
    bool sameDay(DateTime? a, DateTime b) =>
        a != null && a.year == b.year && a.month == b.month && a.day == b.day;
    final counts = await listPoliceReportCounts();
    final monthly = <String, MonthlyReportCount>{};
    for (final r in reports) {
      final d = r.fechaHoraHecho;
      if (d == null) continue;
      final key = '${d.year}-${d.month}';
      monthly[key] = MonthlyReportCount(
          gestion: d.year, mes: d.month, total: (monthly[key]?.total ?? 0) + 1);
    }
    return DashboardStats(
        totalActiveReports: reports.length,
        activePoliceCount: counts.length,
        reportsToday:
            reports.where((r) => sameDay(r.fechaHoraHecho, reference)).length,
        reportsThisMonth: reports
            .where((r) =>
                r.fechaHoraHecho?.year == reference.year &&
                r.fechaHoraHecho?.month == reference.month)
            .length,
        reportsBySelectedDate: reports
            .where((r) => sameDay(r.fechaHoraHecho, selected ?? reference))
            .length,
        reportsByPolice: counts,
        reportsByMonth: monthly.values.toList());
  }

  @override
  Future<DashboardStats> loadAdminDashboard(
      {required DateTime referenceDate, DateTime? selectedDate}) async {
    if (!(await _actor()).isAdmin)
      throw const OnlineException('Se requiere ADMIN.');
    return _dashboard(referenceDate, selectedDate);
  }

  @override
  Future<DashboardStats> loadPoliceDashboard(
      {required int idPolicia,
      required DateTime referenceDate,
      DateTime? selectedDate}) async {
    final a = await _actor();
    if (!a.isPolice || a.requiredPoliceId != idPolicia)
      throw const OnlineException('Se requiere el autor.');
    return _dashboard(referenceDate, selectedDate, police: idPolicia);
  }

  @override
  Future<void> inactivateReport(
          {required int idInforme, DateTime? now}) async =>
      throw const OnlineException(
          'La inactivación en línea no está disponible con el contrato actual.');
  @override
  Future<void> updatePdfPath(
          {required int idInforme,
          required String rutaPdf,
          DateTime? now}) async =>
      throw const OnlineException(
          'Las rutas locales no se guardan en PostgreSQL. Use el protocolo de reserva de PDF.');

  @override
  Future<void> uploadPdf(int reportId, String path) async {
    final actor = await _actor();
    final report = await findActiveReportDetail(reportId);
    if (!actor.isPolice || report?.idPolicia != actor.requiredPoliceId) {
      throw const OnlineException(
          'Solo el autor puede registrar un PDF remoto; ADMIN puede guardarlo en su dispositivo.');
    }
    final uid = gateway.userId!;
    // Conservar reserva e intención ante una respuesta perdida de registrar_pdf.
    final pdfFile = File(path);
    if (await pdfFile.length() > 10485760)
      throw const OnlineException('El PDF excede 10 MiB.');
    final hash = await OnlineFileService.digest(await pdfFile.readAsBytes());
    final key = '$uid/$reportId/$hash';
    final item = _pdfs.putIfAbsent(
        key,
        () => (
              _operationId(),
              PendingOnlineFile(
                  localPath: path, kind: 'PDF', reportId: reportId)
            ));
    await files.prepare(uid, item.$1, [item.$2]);
    await gateway.rpc('registrar_pdf', {'p_reserva': item.$2.reservation});
  }
}

Map<String, dynamic> reportPayload(FinalizeReportInput i) => {
      'epi': i.epi,
      'fecha_hora_llegada': i.fechaHoraLlegada?.toIso8601String(),
      'fecha_hora_hecho': i.fechaHoraHecho?.toIso8601String(),
      'naturaleza': i.naturaleza,
      'lugar': i.lugar,
      'latitud': i.latitud,
      'longitud': i.longitud,
      'denunciante_nombre': i.denuncianteNombre,
      'denunciante_documento': i.denuncianteDocumento,
      'denunciante_contacto': i.denuncianteContacto,
      'descripcion': i.descripcion,
      'condiciones_climaticas': i.condicionesClimaticas,
      'vehiculos_movidos': i.vehiculosMovidos,
      'protagonistas_presentes': i.protagonistasPresentes,
      'testigos': i.testigos,
      'efectos_personales': i.efectosPersonales,
      'conductores': i.conductores
          .map((d) => {
                'nombre_completo': d.nombreCompleto,
                'edad': d.edad,
                'licencia': d.licencia,
                'categoria': d.categoria,
                'domicilio': d.domicilio,
                'zona': d.zona,
                'contactos': d.contactos,
                'condicion_entrega': d.condicionEntrega
              })
          .toList(),
      'vehiculos': i.vehiculos
          .map((v) => {
                'driver_index': v.driverIndex,
                'placa': v.placa,
                'marca': v.marca,
                'color': v.color,
                'tipo': v.tipo,
                'servicio': v.servicio
              })
          .toList(),
      'personas': i.personas
          .map((p) => {
                'nombre': p.nombre,
                'edad': p.edad,
                'tipo': p.tipo,
                'lugar_evacuacion': p.lugarEvacuacion
              })
          .toList(),
    };

ReportRecord mapReport(Map<String, Object?> row) {
  return ReportRecord(
    idInforme: row['id_informe']! as int,
    idPolicia: row['id_policia']! as int,
    gestion: row['gestion']! as int,
    correlativo: row['correlativo']! as int,
    numeroCaso: row['numero_caso']! as String,
    epi: row['epi']! as String,
    fechaHoraLlegada: _parseOptionalDate(row['fecha_hora_llegada']),
    fechaHoraHecho: _parseOptionalDate(row['fecha_hora_hecho']),
    naturaleza: row['naturaleza'] as String?,
    lugar: row['lugar'] as String?,
    latitud: (row['latitud'] as num?)?.toDouble(),
    longitud: (row['longitud'] as num?)?.toDouble(),
    denuncianteNombre: row['denunciante_nombre'] as String?,
    denuncianteDocumento: row['denunciante_documento'] as String?,
    denuncianteContacto: row['denunciante_contacto'] as String?,
    descripcion: row['descripcion'] as String?,
    condicionesClimaticas: row['condiciones_climaticas'] as String?,
    vehiculosMovidos: _intToBool(row['vehiculos_movidos']),
    protagonistasPresentes: _intToBool(row['protagonistas_presentes']),
    testigos: row['testigos'] as String?,
    efectosPersonales: row['efectos_personales'] as String?,
    ownerSnapshot: InstitutionalQrPolice(
      nombreCompleto: row['policia_nombre_snapshot']! as String,
      grado: row['policia_grado_snapshot']! as String,
      numeroPlaca: row['policia_placa_snapshot']! as String,
      unidad: row['policia_unidad_snapshot']! as String,
    ),
    estado: row['estado']! as int,
    fechaCreacion: DateTime.parse(row['fecha_creacion']! as String),
    fechaModificacion: DateTime.parse(row['fecha_modificacion']! as String),
  );
}

DriverRecord mapDriver(Map<String, Object?> row) {
  return DriverRecord(
    idConductor: row['id_conductor']! as int,
    nombreCompleto: row['nombre_completo']! as String,
    edad: row['edad'] as int?,
    licencia: row['licencia'] as String?,
    categoria: row['categoria'] as String?,
    domicilio: row['domicilio'] as String?,
    zona: row['zona'] as String?,
    contactos: row['contactos'] as String?,
    condicionEntrega: row['condicion_entrega'] as String?,
  );
}

VehicleRecord mapVehicle(Map<String, Object?> row) {
  return VehicleRecord(
    idVehiculo: row['id_vehiculo']! as int,
    idConductor: row['id_conductor'] as int?,
    placa: row['placa'] as String?,
    marca: row['marca'] as String?,
    color: row['color'] as String?,
    tipo: row['tipo'] as String?,
    servicio: row['servicio'] as String?,
  );
}

PersonRecord mapPerson(Map<String, Object?> row) {
  return PersonRecord(
    idPersona: row['id_persona']! as int,
    nombre: row['nombre']! as String,
    edad: row['edad'] as int?,
    tipo: row['tipo']! as String,
    lugarEvacuacion: row['lugar_evacuacion'] as String?,
  );
}

DateTime? _parseOptionalDate(Object? v) =>
    v == null ? null : DateTime.parse(v as String);
bool? _intToBool(Object? v) => v == null ? null : v == 1;
