import 'dart:developer' as developer;

import '../database/app_database.dart';
import '../models/report_date_bounds.dart';
import '../database/dao/police_dao.dart';
import '../database/dao/report_dao.dart';
import '../../services/media/evidence_photo.dart';
import '../../services/qr/institutional_qr_service.dart';

import 'report_repository_contract.dart';

export '../models/report_models.dart';

class ReportRepository implements ReportRepositoryContract {
  const ReportRepository(this._database, {this.clock = DateTime.now});

  final AppDatabase _database;
  @override
  final DateTime Function() clock;

  @override
  Future<ReportDateBounds> loadDateBounds({int? idPolicia}) async {
    final db = await _database.instance;
    final earliest =
        await ReportDao(db).earliestReportDate(idPolicia: idPolicia);
    return ReportDateBounds(today: clock(), earliestReportDate: earliest);
  }

  Future<void> _validateQueryDates(ReportQueryFilter filter,
      {int? idPolicia}) async {
    if (filter.from == null && filter.to == null) return;
    // SQLite utiliza un límite superior exclusivo; la UI incluye todo el día.
    final inclusiveEnd = filter.to?.subtract(const Duration(microseconds: 1));
    final bounds = await loadDateBounds(idPolicia: idPolicia);
    final error = bounds.validate(from: filter.from, to: inclusiveEnd);
    if (error != null) throw ReportValidationException([error]);
    if (filter.from != null &&
        filter.to != null &&
        !filter.from!.isBefore(filter.to!)) {
      throw const ReportValidationException([
        'La fecha de inicio no puede ser posterior a la fecha límite.',
      ]);
    }
  }

  Future<void> _validateSelectedDate(DateTime date, {int? idPolicia}) async {
    final bounds = await loadDateBounds(idPolicia: idPolicia);
    final error = bounds.validate(from: date);
    if (error != null) throw ReportValidationException([error]);
  }

  @override
  Future<FinalizedReport> finalizeReport(
    FinalizeReportInput input, {
    DateTime? now,
    PersistPhotosForCase? persistPhotosForCase,
    CleanupPhotos? cleanupPersistedPhotos,
  }) async {
    _validateInput(input);
    var persistedPhotos = <PhotoInput>[];
    try {
      return await _database.transaction((transaction) async {
        final dao = ReportDao(transaction);
        final timestamp = (now ?? DateTime.now()).toIso8601String();
        final correlativo = await dao.nextCorrelativo(input.gestion);
        final numeroCaso = formatCaseNumber(input.gestion, correlativo);

        final idInforme = await dao.insertReport({
          'id_policia': input.idPolicia,
          'gestion': input.gestion,
          'correlativo': correlativo,
          'numero_caso': numeroCaso,
          'epi': input.epi,
          'fecha_hora_llegada': input.fechaHoraLlegada?.toIso8601String(),
          'fecha_hora_hecho': input.fechaHoraHecho?.toIso8601String(),
          'naturaleza': input.naturaleza,
          'lugar': input.lugar,
          'latitud': input.latitud,
          'longitud': input.longitud,
          'denunciante_nombre': input.denuncianteNombre,
          'denunciante_documento': input.denuncianteDocumento,
          'denunciante_contacto': input.denuncianteContacto,
          'descripcion': input.descripcion,
          'condiciones_climaticas': input.condicionesClimaticas,
          'vehiculos_movidos': _boolToInt(input.vehiculosMovidos),
          'protagonistas_presentes': _boolToInt(input.protagonistasPresentes),
          'testigos': input.testigos,
          'efectos_personales': input.efectosPersonales,
          'ruta_croquis': input.rutaCroquis,
          'ruta_pdf': input.rutaPdf,
          'estado': 1,
          'fecha_creacion': timestamp,
          'fecha_modificacion': timestamp,
        });

        final driverIds = <int>[];
        for (final conductor in input.conductores) {
          driverIds.add(
            await dao.insertDriver({
              'id_informe': idInforme,
              'nombre_completo': conductor.nombreCompleto,
              'edad': conductor.edad,
              'licencia': conductor.licencia,
              'categoria': conductor.categoria,
              'domicilio': conductor.domicilio,
              'zona': conductor.zona,
              'contactos': conductor.contactos,
              'condicion_entrega': conductor.condicionEntrega,
              'fecha_creacion': timestamp,
            }),
          );
        }

        for (final vehiculo in input.vehiculos) {
          final driverIndex = vehiculo.driverIndex;
          final idConductor =
              driverIndex == null ? null : driverIds[driverIndex];
          await dao.insertVehicle({
            'id_informe': idInforme,
            'id_conductor': idConductor,
            'placa': vehiculo.placa,
            'marca': vehiculo.marca,
            'color': vehiculo.color,
            'tipo': vehiculo.tipo,
            'servicio': vehiculo.servicio,
            'fecha_creacion': timestamp,
          });
        }

        for (final persona in input.personas) {
          await dao.insertPerson({
            'id_informe': idInforme,
            'nombre': persona.nombre,
            'edad': persona.edad,
            'tipo': persona.tipo,
            'lugar_evacuacion': persona.lugarEvacuacion,
            'fecha_creacion': timestamp,
          });
        }

        persistedPhotos = input.fotografias.isEmpty
            ? const []
            : persistPhotosForCase == null
                ? input.fotografias
                : await persistPhotosForCase(
                    numeroCaso: numeroCaso,
                    photos: input.fotografias,
                  );

        for (final fotografia in persistedPhotos) {
          await dao.insertPhoto({
            'id_informe': idInforme,
            'ruta': fotografia.ruta,
            'tipo': fotografia.tipo.databaseValue,
            'descripcion': fotografia.descripcion,
            'fecha_creacion': timestamp,
          });
        }

        return FinalizedReport(
          idInforme: idInforme,
          gestion: input.gestion,
          correlativo: correlativo,
          numeroCaso: numeroCaso,
        );
      });
    } catch (_) {
      if (persistPhotosForCase != null &&
          persistedPhotos.isNotEmpty &&
          cleanupPersistedPhotos != null) {
        try {
          await cleanupPersistedPhotos(persistedPhotos);
        } catch (error) {
          developer.log(
              'No se pudo limpiar evidencia tras rollback (${error.runtimeType}).',
              name: 'acc_transito');
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> findActiveReports() async {
    final db = await _database.instance;
    return ReportDao(db).findActiveReports();
  }

  Future<List<ReportRecord>> listActiveReportsForAdmin() async {
    return queryActiveReportsForAdmin();
  }

  @override
  Future<List<ReportRecord>> queryActiveReportsForAdmin({
    ReportQueryFilter filter = const ReportQueryFilter(),
  }) async {
    await _validateQueryDates(filter);
    final db = await _database.instance;
    final rows = await ReportDao(db).findActiveReportsFiltered(
      idPolicia: filter.idPolicia,
      from: filter.from,
      to: filter.to,
    );
    return rows.map(_mapReport).toList(growable: false);
  }

  Future<List<ReportRecord>> listActiveReportsForPolice(int idPolicia) async {
    return queryActiveReportsForPolice(idPolicia: idPolicia);
  }

  @override
  Future<List<ReportRecord>> queryActiveReportsForPolice({
    required int idPolicia,
    ReportQueryFilter filter = const ReportQueryFilter(),
  }) async {
    await _validateQueryDates(filter, idPolicia: idPolicia);
    final db = await _database.instance;
    final rows = await ReportDao(db).findActiveReportsFiltered(
      idPolicia: idPolicia,
      from: filter.from,
      to: filter.to,
    );
    return rows.map(_mapReport).toList(growable: false);
  }

  @override
  Future<ReportRecord?> findActiveReportDetail(int idInforme) async {
    final db = await _database.instance;
    final dao = ReportDao(db);
    final report = await dao.findActiveById(idInforme);
    if (report == null) {
      return null;
    }
    return _mapReport(report).copyWith(
      conductores: (await dao.findDrivers(idInforme)).map(_mapDriver).toList(),
      vehiculos: (await dao.findVehicles(idInforme)).map(_mapVehicle).toList(),
      personas: (await dao.findPeople(idInforme)).map(_mapPerson).toList(),
      fotografias: (await dao.findPhotos(idInforme)).map(_mapPhoto).toList(),
    );
  }

  @override
  Future<ReportRecord?> findActiveReportDetailForPolice({
    required int idInforme,
    required int idPolicia,
  }) async {
    final db = await _database.instance;
    final dao = ReportDao(db);
    final report = await dao.findActiveByIdForPolice(idInforme, idPolicia);
    if (report == null) {
      return null;
    }
    return _mapReport(report).copyWith(
      conductores: (await dao.findDrivers(idInforme)).map(_mapDriver).toList(),
      vehiculos: (await dao.findVehicles(idInforme)).map(_mapVehicle).toList(),
      personas: (await dao.findPeople(idInforme)).map(_mapPerson).toList(),
      fotografias: (await dao.findPhotos(idInforme)).map(_mapPhoto).toList(),
    );
  }

  @override
  Future<InstitutionalQrPolice> findReportOwnerQrIdentity(
    int idPolicia,
  ) async {
    final db = await _database.instance;
    final row = await PoliceDao(db).findById(idPolicia);
    if (row == null) {
      throw StateError('No se encontró el policía propietario del informe.');
    }
    return InstitutionalQrPolice(
      nombreCompleto:
          '${row['nombres'] as String} ${row['apellidos'] as String}'.trim(),
      grado: row['grado'] as String,
      numeroPlaca: row['numero_placa'] as String,
      unidad: row['unidad'] as String,
    );
  }

  @override
  Future<DashboardStats> loadAdminDashboard({
    required DateTime referenceDate,
    DateTime? selectedDate,
  }) async {
    await _validateSelectedDate(selectedDate ?? referenceDate);
    final db = await _database.instance;
    final dao = ReportDao(db);
    final todayRange = _dayRange(referenceDate);
    final monthRange = _monthRange(referenceDate);
    final selectedRange = _dayRange(selectedDate ?? referenceDate);

    return DashboardStats(
      totalActiveReports: await dao.countActiveReports(),
      activePoliceCount: await dao.countActivePolice(),
      reportsToday: await dao.countActiveReportsFromTo(
        from: todayRange.$1,
        to: todayRange.$2,
      ),
      reportsThisMonth: await dao.countActiveReportsFromTo(
        from: monthRange.$1,
        to: monthRange.$2,
      ),
      reportsBySelectedDate: await dao.countActiveReportsFromTo(
        from: selectedRange.$1,
        to: selectedRange.$2,
      ),
      reportsByPolice: (await dao.countActiveReportsByPolice())
          .map(_mapPoliceReportCount)
          .toList(growable: false),
      reportsByMonth: (await dao.countActiveReportsByMonth())
          .map(_mapMonthlyReportCount)
          .toList(growable: false),
    );
  }

  @override
  Future<DashboardStats> loadPoliceDashboard({
    required int idPolicia,
    required DateTime referenceDate,
    DateTime? selectedDate,
  }) async {
    await _validateSelectedDate(selectedDate ?? referenceDate,
        idPolicia: idPolicia);
    final db = await _database.instance;
    final dao = ReportDao(db);
    final todayRange = _dayRange(referenceDate);
    final monthRange = _monthRange(referenceDate);
    final selectedRange = _dayRange(selectedDate ?? referenceDate);

    return DashboardStats(
      totalActiveReports: await dao.countActiveReports(idPolicia: idPolicia),
      activePoliceCount: 0,
      reportsToday: await dao.countActiveReportsFromTo(
        from: todayRange.$1,
        to: todayRange.$2,
        idPolicia: idPolicia,
      ),
      reportsThisMonth: await dao.countActiveReportsFromTo(
        from: monthRange.$1,
        to: monthRange.$2,
        idPolicia: idPolicia,
      ),
      reportsBySelectedDate: await dao.countActiveReportsFromTo(
        from: selectedRange.$1,
        to: selectedRange.$2,
        idPolicia: idPolicia,
      ),
      reportsByPolice: const [],
      reportsByMonth: (await dao.countActiveReportsByMonth(
        idPolicia: idPolicia,
      ))
          .map(_mapMonthlyReportCount)
          .toList(growable: false),
    );
  }

  @override
  Future<List<PoliceReportCount>> listPoliceReportCounts() async {
    final db = await _database.instance;
    return (await ReportDao(db).countActiveReportsByPolice())
        .map(_mapPoliceReportCount)
        .toList(growable: false);
  }

  @override
  Future<void> inactivateReport({
    required int idInforme,
    DateTime? now,
  }) async {
    final db = await _database.instance;
    final updatedRows = await ReportDao(db).inactivateReport(
      idInforme,
      (now ?? DateTime.now()).toIso8601String(),
    );
    if (updatedRows != 1) {
      throw StateError('No se pudo inactivar el informe $idInforme.');
    }
  }

  @override
  Future<void> updatePdfPath({
    required int idInforme,
    required String rutaPdf,
    DateTime? now,
  }) async {
    final db = await _database.instance;
    final updatedRows = await ReportDao(db).updatePdfPath(
      idInforme,
      rutaPdf,
      (now ?? DateTime.now()).toIso8601String(),
    );
    if (updatedRows != 1) {
      throw StateError(
          'No se pudo guardar la ruta PDF del informe $idInforme.');
    }
  }

  static String formatCaseNumber(int gestion, int correlativo) {
    return '$gestion-${correlativo.toString().padLeft(6, '0')}';
  }

  static void _validateInput(FinalizeReportInput input) {
    final messages = <String>[];
    void requiredText(String label, String? value) {
      if ((value ?? '').trim().isEmpty) {
        messages.add('Debe ingresar $label.');
      }
    }

    if (input.idPolicia <= 0) {
      messages.add('El informe debe asociarse a un policía válido.');
    }
    if (input.gestion < 2000) {
      messages.add('La gestión del informe no es válida.');
    }
    requiredText('EPI / Estación Policial Integral', input.epi);
    if (input.fechaHoraLlegada == null) {
      messages.add('Debe ingresar fecha y hora de llegada.');
    }
    if (input.fechaHoraHecho == null) {
      messages.add('Debe ingresar fecha y hora del hecho.');
    }
    requiredText('naturaleza', input.naturaleza);
    requiredText('lugar', input.lugar);
    requiredText('denunciante', input.denuncianteNombre);
    requiredText('contacto del denunciante', input.denuncianteContacto);
    requiredText('descripción', input.descripcion);
    requiredText('condiciones climáticas', input.condicionesClimaticas);
    if (input.vehiculosMovidos == null) {
      messages.add('Debe indicar si los vehículos fueron movidos.');
    }
    if (input.protagonistasPresentes == null) {
      messages.add('Debe indicar si los protagonistas están presentes.');
    }
    requiredText('testigos', input.testigos);
    requiredText('efectos personales', input.efectosPersonales);

    if ((input.latitud == null) != (input.longitud == null)) {
      messages.add('Ingrese latitud y longitud, o deje ambas vacías.');
    }
    if (input.latitud != null &&
        (!input.latitud!.isFinite || input.latitud!.abs() > 90)) {
      messages.add('La latitud debe estar entre -90 y 90.');
    }
    if (input.longitud != null &&
        (!input.longitud!.isFinite || input.longitud!.abs() > 180)) {
      messages.add('La longitud debe estar entre -180 y 180.');
    }

    for (final (index, conductor) in input.conductores.indexed) {
      requiredText(
          'nombre del conductor ${index + 1}', conductor.nombreCompleto);
      if (conductor.edad != null && conductor.edad! < 0) {
        messages.add('La edad del conductor ${index + 1} no es válida.');
      }
      requiredText('licencia del conductor ${index + 1}', conductor.licencia);
      requiredText('categoría del conductor ${index + 1}', conductor.categoria);
    }
    for (final (index, vehiculo) in input.vehiculos.indexed) {
      requiredText('placa del vehículo ${index + 1}', vehiculo.placa);
      requiredText('marca del vehículo ${index + 1}', vehiculo.marca);
      requiredText('color del vehículo ${index + 1}', vehiculo.color);
      requiredText('tipo del vehículo ${index + 1}', vehiculo.tipo);
      requiredText('servicio del vehículo ${index + 1}', vehiculo.servicio);
      final driverIndex = vehiculo.driverIndex;
      if (driverIndex != null &&
          (driverIndex < 0 || driverIndex >= input.conductores.length)) {
        messages
            .add('El vehículo ${index + 1} referencia un conductor inválido.');
      }
    }
    for (final (index, persona) in input.personas.indexed) {
      requiredText(
          'nombre de la persona involucrada ${index + 1}', persona.nombre);
      if (persona.tipo != 'HERIDO' && persona.tipo != 'FALLECIDO') {
        messages.add('El tipo de persona ${index + 1} no es válido.');
      }
      if (persona.edad == null) {
        messages.add('Debe ingresar edad de la persona ${index + 1}.');
      } else if (persona.edad! < 0) {
        messages.add('La edad de la persona ${index + 1} no es válida.');
      }
    }
    for (final (index, fotografia) in input.fotografias.indexed) {
      requiredText('ruta de fotografía ${index + 1}', fotografia.ruta);
    }

    if (messages.isNotEmpty) {
      throw ReportValidationException(messages);
    }
  }

  static ReportRecord _mapReport(Map<String, Object?> row) {
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
      rutaCroquis: row['ruta_croquis'] as String?,
      rutaPdf: row['ruta_pdf'] as String?,
      estado: row['estado']! as int,
      fechaCreacion: DateTime.parse(row['fecha_creacion']! as String),
      fechaModificacion: DateTime.parse(row['fecha_modificacion']! as String),
    );
  }

  static DriverRecord _mapDriver(Map<String, Object?> row) {
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

  static VehicleRecord _mapVehicle(Map<String, Object?> row) {
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

  static PersonRecord _mapPerson(Map<String, Object?> row) {
    return PersonRecord(
      idPersona: row['id_persona']! as int,
      nombre: row['nombre']! as String,
      edad: row['edad'] as int?,
      tipo: row['tipo']! as String,
      lugarEvacuacion: row['lugar_evacuacion'] as String?,
    );
  }

  static PhotoRecord _mapPhoto(Map<String, Object?> row) {
    return PhotoRecord(
      idFotografia: row['id_fotografia']! as int,
      ruta: row['ruta']! as String,
      tipo: EvidencePhotoCategory.fromDatabase(row['tipo']! as String),
      descripcion: row['descripcion'] as String?,
    );
  }

  static PoliceReportCount _mapPoliceReportCount(Map<String, Object?> row) {
    return PoliceReportCount(
      idPolicia: row['id_policia']! as int,
      grado: row['grado']! as String,
      nombres: row['nombres']! as String,
      apellidos: row['apellidos']! as String,
      numeroPlaca: row['numero_placa']! as String,
      total: row['total']! as int,
    );
  }

  static MonthlyReportCount _mapMonthlyReportCount(Map<String, Object?> row) {
    return MonthlyReportCount(
      gestion: row['gestion']! as int,
      mes: row['mes']! as int,
      total: row['total']! as int,
    );
  }

  static (DateTime, DateTime) _dayRange(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return (start, start.add(const Duration(days: 1)));
  }

  static (DateTime, DateTime) _monthRange(DateTime date) {
    final start = DateTime(date.year, date.month);
    return (start, DateTime(date.year, date.month + 1));
  }

  static int? _boolToInt(bool? value) {
    if (value == null) {
      return null;
    }
    return value ? 1 : 0;
  }

  static bool? _intToBool(Object? value) {
    if (value == null) {
      return null;
    }
    return value == 1;
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }
}
