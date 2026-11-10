import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_acc_transito/app/app.dart';
import 'package:app_acc_transito/app/mode_selection.dart';
import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/models/report_models.dart';
import 'package:app_acc_transito/data/remote/online_file_service.dart';
import 'package:app_acc_transito/data/remote/online_report_repository.dart';
import 'package:app_acc_transito/data/remote/remote_gateway.dart';
import 'package:app_acc_transito/features/auth/application/auth_controller.dart';
import 'package:app_acc_transito/features/auth/data/online_auth_repository.dart';
import 'package:app_acc_transito/features/auth/domain/auth_exceptions.dart';
import 'package:app_acc_transito/features/reports/application/report_controller.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException, StorageException;

const adminUid = '10000000-0000-4000-8000-000000000001';
const aUid = '10000000-0000-4000-8000-000000000002';
const bUid = '10000000-0000-4000-8000-000000000003';

/// Modelo del contrato para probar al cliente. No demuestra RLS de PostgreSQL.
class FakeServer {
  final users = <Map<String, dynamic>>[
    {
      'id_usuario': 1,
      'auth_uid': adminUid,
      'nombre_usuario': 'admin',
      'rol': 'ADMIN',
      'estado': 1
    },
    {
      'id_usuario': 2,
      'auth_uid': aUid,
      'nombre_usuario': 'police-a',
      'rol': 'POLICE',
      'estado': 1
    },
    {
      'id_usuario': 3,
      'auth_uid': bUid,
      'nombre_usuario': 'police-b',
      'rol': 'POLICE',
      'estado': 1
    },
  ];
  final police = [
    for (var i = 2; i <= 3; i++)
      <String, dynamic>{
        'id_policia': i,
        'id_usuario': i,
        'numero_placa': 'FICTICIA-$i',
        'grado': 'Grado ficticio',
        'nombres': 'Histórico $i',
        'apellidos': 'Ficticio',
        'unidad': 'Unidad ficticia',
        'sigla': 'DEMO',
        'ci': 'FICTICIO-$i',
        'estado': 1,
      }
  ];
  final reports = <Map<String, dynamic>>[];
  final drivers = <Map<String, dynamic>>[];
  final ledger = <String, Map<String, dynamic>>{};
  final reservations = <Map<String, dynamic>>[];
  final archives = <Map<String, dynamic>>[];
  final photos = <Map<String, dynamic>>[];
  final objects = <String, Uint8List>{};
  int verifications = 0;
  int activeFiles = 0;
  int maxActiveFiles = 0;
}

class FakeGateway implements RemoteGateway {
  FakeGateway(this.server, [this.userId = aUid]);
  final FakeServer server;
  @override
  String? userId;
  final events = StreamController<bool>.broadcast(sync: true);
  bool offline = false;
  int lostResponses = 0;
  Object? rpcError;
  Object? verificationError;
  bool loseVerificationResponse = false;
  Completer<void>? rpcGate;
  final calls = <Map<String, dynamic>>[];
  final reads = <String>[];
  @override
  Stream<bool> get sessionChanges => events.stream;
  void _network() {
    if (offline) throw const SocketException('offline sintético');
  }

  @override
  Future<void> signIn(String email, String password) async {
    _network();
    userId = switch (email) {
      'admin@example.invalid' => adminUid,
      'a@example.invalid' => aUid,
      'b@example.invalid' => bUid,
      _ => throw const AuthException('Ingreso rechazado')
    };
    events.add(true);
  }

  @override
  Future<void> signOut() async {
    userId = null;
    events.add(false);
  }

  @override
  Future<List<Map<String, dynamic>>> select(String table,
      {Map<String, Object> equals = const {}}) async {
    _network();
    reads.add(table);
    if (userId == null) return [];
    final actor = server.users.singleWhere((u) => u['auth_uid'] == userId);
    if (actor['estado'] != 1) return [];
    final admin = actor['rol'] == 'ADMIN';
    final own = actor['id_usuario'];
    bool accessibleReport(Object? id) => server.reports.any((r) =>
        r['id_informe'] == id &&
        r['estado'] == 1 &&
        (admin || r['id_policia'] == own));
    final List<Map<String, dynamic>> rows = switch (table) {
      'usuarios' =>
        server.users.where((u) => admin || u['id_usuario'] == own).toList(),
      'policias' =>
        server.police.where((p) => admin || p['id_usuario'] == own).toList(),
      'informes' =>
        server.reports.where((r) => accessibleReport(r['id_informe'])).toList(),
      'archivos_informe' => server.archives
          .where((r) => accessibleReport(r['id_informe']))
          .toList(),
      'fotografias' =>
        server.photos.where((r) => accessibleReport(r['id_informe'])).toList(),
      'reservas_archivos' => server.reservations
          .where((r) =>
              r['auth_uid'] == userId || accessibleReport(r['id_informe']))
          .toList(),
      'conductores' =>
        server.drivers.where((r) => accessibleReport(r['id_informe'])).toList(),
      'vehiculos' || 'personas_involucradas' => [],
      _ => throw StateError('Tabla no autorizada: $table'),
    };
    return rows
        .where((r) => equals.entries.every((e) => r[e.key] == e.value))
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  @override
  Future<dynamic> rpc(String name, Map<String, dynamic> parameters) async {
    _network();
    calls.add(jsonDecode(jsonEncode({'name': name, ...parameters}))
        as Map<String, dynamic>);
    if (rpcGate != null) await rpcGate!.future;
    if (rpcError != null) throw rpcError!;
    if (name == 'reservar_archivo') {
      final id = parameters['p_reserva'];
      final existing = server.reservations.where((r) => r['reserva_id'] == id);
      if (existing.isNotEmpty) return existing.single;
      final r = <String, dynamic>{
        'reserva_id': id,
        'auth_uid': userId,
        'operation_id': parameters['p_operacion'],
        'clase': parameters['p_clase'],
        'tipo': parameters['p_tipo'],
        'mime': parameters['p_mime'],
        'bucket_id': parameters['p_clase'] == 'PDF'
            ? 'transito-pdf'
            : 'transito-evidencias',
        'objeto': '$userId/${parameters['p_operacion']}/$id',
        'estado': 'RESERVADO',
        'id_informe': parameters['p_informe']
      };
      server.reservations.add(r);
      return r;
    }
    if (name == 'registrar_pdf') {
      final r = server.reservations
          .singleWhere((r) => r['reserva_id'] == parameters['p_reserva']);
      if (r['estado'] != 'VINCULADO') _link(r, r['id_informe']);
      return r['id_archivo'];
    }
    if (name != 'finalizar_informe') throw StateError('RPC inventada');
    final op = parameters['operation_id'] as String;
    final payload = parameters['payload'] as Map<String, dynamic>;
    var entry = server.ledger[op];
    if (entry != null) {
      if (entry['uid'] != userId)
        throw const PostgrestException(message: 'ajeno', code: '42501');
      if (entry['payload'] != jsonEncode(payload))
        throw const PostgrestException(message: 'conflicto', code: 'PT409');
    } else {
      final n = server.reports.length + 1;
      final result = {
        'id_informe': n,
        'gestion': 2026,
        'correlativo': n,
        'numero_caso': '2026-${n.toString().padLeft(6, '0')}'
      };
      entry = {'uid': userId, 'payload': jsonEncode(payload), 'result': result};
      server.ledger[op] = entry;
      final actor = server.users.singleWhere((u) => u['auth_uid'] == userId);
      final p = server.police
          .singleWhere((p) => p['id_usuario'] == actor['id_usuario']);
      server.reports.add({
        ...payload,
        ...result,
        'id_policia': p['id_policia'],
        'estado': 1,
        'fecha_creacion': '2026-10-29T12:00:00.000Z',
        'fecha_modificacion': '2026-10-29T12:00:00.000Z',
        'policia_nombre_snapshot': '${p['nombres']} ${p['apellidos']}',
        'policia_grado_snapshot': p['grado'],
        'policia_placa_snapshot': p['numero_placa'],
        'policia_unidad_snapshot': p['unidad']
      });
      for (final driver in payload['conductores'] as List? ?? []) {
        server.drivers.add({
          ...Map<String, dynamic>.from(driver as Map),
          'id_conductor': server.drivers.length + 1,
          'id_informe': n,
        });
      }
      for (final id in payload['archivos'] as List? ?? []) {
        _link(server.reservations.singleWhere((r) => r['reserva_id'] == id), n);
      }
    }
    if (lostResponses > 0) {
      lostResponses--;
      throw TimeoutException('respuesta perdida tras commit simulado');
    }
    return entry['result'];
  }

  void _link(Map<String, dynamic> r, int report) {
    final id = server.archives.length + 1;
    r.addAll({'id_informe': report, 'id_archivo': id, 'estado': 'VINCULADO'});
    server.archives.add({...r});
    if (r['clase'] == 'FOTOGRAFIA')
      server.photos.add({
        'id_fotografia': id,
        'id_archivo': id,
        'id_informe': report,
        'tipo': r['tipo']
      });
  }

  Future<T> _file<T>(Future<T> Function() action) async {
    _network();
    server.activeFiles++;
    if (server.activeFiles > server.maxActiveFiles)
      server.maxActiveFiles = server.activeFiles;
    try {
      await Future<void>.delayed(Duration.zero);
      return await action();
    } finally {
      server.activeFiles--;
    }
  }

  @override
  Future<void> upload(
          String bucket, String object, Uint8List bytes, String mime) =>
      _file(() async {
        if (server.objects.containsKey('$bucket/$object'))
          throw StateError('overwrite prohibido');
        server.objects['$bucket/$object'] = bytes;
      });
  @override
  Future<Uint8List> download(String bucket, String object) =>
      _file(() async => server.objects['$bucket/$object']!);
  @override
  Future<void> verify(String reservation) => _file(() async {
        server.verifications++;
        if (verificationError != null) throw verificationError!;
        server.reservations
                .singleWhere((r) => r['reserva_id'] == reservation)['estado'] =
            'VERIFICADO';
        if (loseVerificationResponse) {
          loseVerificationResponse = false;
          throw TimeoutException(
              'verificación confirmada con respuesta perdida simulada');
        }
      });
}

class BombDatabase extends AppDatabase {
  @override
  Future<Database> get instance => throw StateError('ONLINE tocó SQLite');
}

FinalizeReportInput input(
        {int police = 2,
        String place = 'Lugar ficticio',
        String unit = 'EPI ficticia',
        String nature = 'Colisión',
        String complainant = 'Persona ficticia',
        String description = 'Descripción ficticia',
        List<DriverInput> drivers = const [],
        List<PhotoInput> photos = const [],
        String? sketch}) =>
    FinalizeReportInput(
        idPolicia: police,
        gestion: 2026,
        epi: unit,
        fechaHoraLlegada: DateTime(2026, 10, 29, 10),
        fechaHoraHecho: DateTime(2026, 10, 29, 9),
        naturaleza: nature,
        lugar: place,
        denuncianteNombre: complainant,
        denuncianteContacto: 'Contacto ficticio',
        descripcion: description,
        condicionesClimaticas: 'Sin novedad',
        vehiculosMovidos: false,
        protagonistasPresentes: true,
        testigos: 'Sin testigos',
        efectosPersonales: 'Sin efectos',
        conductores: drivers,
        fotografias: photos,
        rutaCroquis: sketch);

DirectActionReportDraft draft() => DirectActionReportDraft(
    epi: 'EPI ficticia',
    fechaHoraLlegada: DateTime(2026, 10, 29, 10),
    fechaHoraHecho: DateTime(2026, 10, 29, 9),
    naturaleza: 'Colisión',
    lugar: 'Lugar ficticio',
    denuncianteNombre: 'Persona ficticia',
    denuncianteDocumento: '',
    denuncianteContacto: 'Contacto ficticio',
    descripcion: 'Descripción sintética',
    condicionesClimaticas: 'Sin novedad',
    vehiculosMovidos: false,
    protagonistasPresentes: true,
    testigos: 'Sin testigos',
    efectosPersonales: 'Sin efectos');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeServer server;
  late FakeGateway a;
  late OnlineReportRepository reports;
  setUp(() {
    server = FakeServer();
    a = FakeGateway(server);
    reports = OnlineReportRepository(a);
  });

  test('Auth roles proceden de usuarios/perfil activo y restaura/cierra sesión',
      () async {
    final auth = AuthController(OnlineAuthRepository(a));
    await auth.restoreSession();
    expect(auth.currentUser!.isPolice, isTrue);
    expect(auth.currentUser!.requiredPoliceId, 2);
    await auth.login(
        username: 'admin@example.invalid', password: 'ficticia-123');
    expect(auth.currentUser!.isAdmin, isTrue);
    await auth.logout();
    expect(a.userId, isNull);
    expect(auth.currentUser, isNull);
    auth.dispose();
  });
  test('cuenta inactiva/perfil inexistente/rol desconocido se rechazan',
      () async {
    server.users[1]['estado'] = 0;
    await expectLater(OnlineAuthRepository(a).restoreSession(),
        throwsA(isA<InactiveUserException>()));
    server.users[1]['estado'] = 1;
    server.police.clear();
    await expectLater(OnlineAuthRepository(a).restoreSession(),
        throwsA(isA<MissingPoliceProfileException>()));
    server.users[1]['rol'] = 'DESCONOCIDO';
    await expectLater(OnlineAuthRepository(a).restoreSession(),
        throwsA(isA<AuthorizationException>()));
  });
  test('expiración y error de renovación no quedan sin manejar', () async {
    final auth = AuthController(OnlineAuthRepository(a));
    await auth.restoreSession();
    a.events.addError(const SocketException('offline sintético'));
    expect(auth.connectionMessage, isNotNull);
    a.userId = null;
    a.events.add(false);
    expect(auth.currentUser, isNull);
    auth.dispose();
  });
  test('ADMIN agregado y POLICE propios con tres clientes simulados', () async {
    await reports.finalizeReport(input());
    final b = OnlineReportRepository(FakeGateway(server, bUid));
    expect(await b.findActiveReportDetailForPolice(idInforme: 1, idPolicia: 3),
        isNull);
    await expectLater(b.queryActiveReportsForPolice(idPolicia: 2),
        throwsA(isA<OnlineException>()));
    await b.finalizeReport(input(police: 3));
    final admin = OnlineReportRepository(FakeGateway(server, adminUid));
    final anotherAdmin = OnlineReportRepository(FakeGateway(server, adminUid));
    expect((await admin.queryActiveReportsForAdmin()).length, 2);
    expect(
        (await anotherAdmin.queryActiveReportsForAdmin())
            .map((r) => r.idInforme),
        [2, 1]);
    expect((await reports.queryActiveReportsForPolice(idPolicia: 2)).length, 1);
    await expectLater(
        reports.queryActiveReportsForAdmin(), throwsA(isA<OnlineException>()));
  });
  test('refrescar propaga la escritura desde otro cliente sin cache local',
      () async {
    final admin = ReportController(
        repository: OnlineReportRepository(FakeGateway(server, adminUid)));
    final actor = (await OnlineAuthRepository(FakeGateway(server, adminUid))
        .restoreSession())!;
    await admin.load(actor);
    expect(admin.reports, isEmpty);
    await reports.finalizeReport(input());
    await admin.load(actor);
    expect(admin.reports.length, 1);
    admin.dispose();
  });
  test('formulario actualizado conserva campos en otro cliente ONLINE',
      () async {
    const natures = [
      'ARROLLAMIENTO',
      'ATRICCION',
      'ATROPELLO',
      'CAIDA',
      'CHOQUE',
      'COLISION',
      'DESLIZAMIENTO',
      'EMBARRANCAMIENTO',
      'ENCUNETAMIENTO',
      'OTROS HECHOS DE TRANSITO',
      'SUMERSION',
      'VUELCO'
    ];
    const units = [
      'EPI 3',
      'EPI 5',
      'EPI 6',
      'EPI 8',
      'EPI 9',
      'EPI 11',
      'RP 110',
      'TRANSITO',
      'UPAR DELTA',
      'PAC',
      'DIPROVE',
      'POFOMA',
      'INTERPOL',
      'BOMBEROS',
      'BATALLON DE SEGURIDAD FISICA'
    ];
    const categories = ['A', 'B', 'C', 'M', 'P', 'T', 'Otros'];
    const complainants = [
      'BOL 110',
      'DE OFICIO',
      'DENUNCIANTE: Persona ficticia Áñez',
      'OTRO: Persona ficticia Muñoz'
    ];
    const description =
        'Texto dictado ficticio.\nCorrección revisada con ñ y acentos.';
    final admin = OnlineReportRepository(FakeGateway(server, adminUid));
    final anotherPolice = OnlineReportRepository(FakeGateway(server));
    final forbidden = OnlineReportRepository(FakeGateway(server, bUid));
    for (var i = 0; i < units.length; i++) {
      a.lostResponses = 1;
      final result = await reports.finalizeReport(input(
          unit: units[i],
          nature: natures[i % natures.length],
          complainant: complainants[i % 4],
          description: description,
          drivers: [
            DriverInput(
                nombreCompleto: 'Conductor ficticio',
                licencia: 'FICTICIA',
                categoria: categories[i % 7],
                condicionEntrega: 'Observación ficticia')
          ]));
      for (final reader in [admin, anotherPolice]) {
        final row = (await reader.findActiveReportDetail(result.idInforme))!;
        expect(row.epi, units[i]);
        expect(row.naturaleza, natures[i % natures.length]);
        expect(row.denuncianteNombre, complainants[i % 4]);
        expect(row.descripcion, description);
        expect(row.conductores.single.categoria, categories[i % 7]);
        expect(row.conductores.single.condicionEntrega, 'Observación ficticia');
      }
      expect(await forbidden.findActiveReportDetail(result.idInforme), isNull);
    }
    expect(server.reports.length, 15);
    expect(server.drivers.length, 15);
    expect(server.ledger.length, 15);
  });
  test('offline propaga error y borra resultados visibles; nunca fallback',
      () async {
    await reports.finalizeReport(input());
    final controller = ReportController(repository: reports);
    final actor = (await OnlineAuthRepository(a).restoreSession())!;
    await controller.load(actor);
    expect(controller.reports, isNotEmpty);
    a.offline = true;
    await controller.load(actor);
    expect(controller.errorMessage, isNotNull);
    expect(controller.reports, isEmpty);
    controller.dispose();
  });
  test('respuesta perdida tras commit: replay exacto, un informe, dos llamadas',
      () async {
    a.lostResponses = 1;
    final r = await reports.finalizeReport(input());
    expect(r.numeroCaso, '2026-000001');
    expect(server.reports.length, 1);
    expect(a.calls.length, 2);
    expect(a.calls[0], a.calls[1]);
    expect(reports.hasPendingFinalization, isFalse);
  });
  test(
      'incertidumbre conserva operación tras dos intentos y recuperación manual',
      () async {
    a.lostResponses = 2;
    await expectLater(
        reports.finalizeReport(input()), throwsA(isA<OnlineException>()));
    expect(a.calls.length, 2);
    expect(reports.hasPendingFinalization, isTrue);
    await expectLater(reports.beginReport(), throwsA(isA<OnlineException>()));
    await expectLater(reports.finalizeReport(input(place: 'Otro contenido')),
        throwsA(isA<OnlineException>()));
    expect(a.calls.length, 2);
    final r = await reports.resumeFinalization();
    expect(r.idInforme, 1);
    expect(server.reports.length, 1);
    expect(a.calls[2], a.calls[0]);
  });
  test('doble toque en controlador comparte una sola finalización', () async {
    a.rpcGate = Completer<void>();
    final controller = ReportController(repository: reports);
    final actor = (await OnlineAuthRepository(a).restoreSession())!;
    final first = controller.finalize(actor: actor, draft: draft());
    final second = controller.finalize(actor: actor, draft: draft());
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    a.rpcGate!.complete();
    await Future.wait([first, second]);
    expect(a.calls.length, 1);
    controller.dispose();
  });
  for (final code in ['42501', '22023', 'PT409', 'PT422', '546']) {
    test('error $code no dispara replay', () async {
      a.rpcError = PostgrestException(message: 'error sintético', code: code);
      await expectLater(
          reports.finalizeReport(input()), throwsA(isA<OnlineException>()));
      expect(a.calls.length, 1);
      if (code == '546') {
        await expectLater(
            reports.resumeFinalization(), throwsA(isA<OnlineException>()));
        expect(a.calls.length, 1);
      }
    });
  }
  test('operación pendiente no se recupera desde otro actor', () async {
    a.lostResponses = 2;
    await expectLater(
        reports.finalizeReport(input()), throwsA(isA<OnlineException>()));
    a.userId = bUid;
    await expectLater(
        reports.resumeFinalization(), throwsA(isA<OnlineException>()));
    a.userId = aUid;
    expect((await reports.resumeFinalization()).idInforme, 1);
  });
  test('snapshot del informe alimenta QR/PDF aunque cambie el policía',
      () async {
    await reports.finalizeReport(input());
    server.police[0]['nombres'] = 'Perfil cambiado';
    await reports.finalizeReport(input(place: 'Segundo informe'));
    final controller = ReportController(repository: reports);
    final actor = (await OnlineAuthRepository(a).restoreSession())!;
    expect(
        (await controller.findReadableOwner(actor: actor, idInforme: 1))
            .nombreCompleto,
        'Histórico 2 Ficticio');
    expect(
        (await controller.findReadableOwner(actor: actor, idInforme: 2))
            .nombreCompleto,
        'Perfil cambiado Ficticio');
    final pdf = await controller.buildReadablePdf(actor: actor, idInforme: 1);
    expect(pdf.bytes, isNotEmpty);
    expect(pdf.qrPayload.nombreCompleto, 'Histórico 2 Ficticio');
    controller.dispose();
  });
  test('gateway SDK usa parámetros RPC reales y no reintenta 546', () async {
    var n = 0;
    final client =
        SupabaseClient('https://example.invalid', 'public-client-test',
            httpClient: MockClient((request) async {
      n++;
      expect(request.url.path, '/rest/v1/rpc/finalizar_informe');
      expect(jsonDecode(request.body),
          {'operation_id': 'sintético', 'payload': {}});
      return http.Response('{"message":"error sintético","code":"546"}', 546,
          request: request, headers: {'content-type': 'application/json'});
    }));
    await expectLater(
        SupabaseGateway(client).rpc(
            'finalizar_informe', {'operation_id': 'sintético', 'payload': {}}),
        throwsA(isA<PostgrestException>()));
    expect(n, 1);
    await client.dispose();
  });
  test('SDK no reintenta verificación 546 ni carga Storage 503', () async {
    var n = 0;
    final client =
        SupabaseClient('https://example.invalid', 'public-client-test',
            httpClient: MockClient((request) async {
      n++;
      if (request.url.path.contains('/functions/')) {
        expect(jsonDecode(request.body), {'reserva_id': 'reserva-sintética'});
        return http.Response('{"message":"error sintético"}', 546,
            request: request, headers: {'content-type': 'application/json'});
      }
      expect(request.headers['x-upsert'], 'false');
      return http.Response(
          '{"message":"error sintético","statusCode":"503"}', 503,
          request: request, headers: {'content-type': 'application/json'});
    }));
    final gateway = SupabaseGateway(client);
    await expectLater(
        gateway.verify('reserva-sintética'),
        throwsA(isA<OnlineException>()
            .having((e) => e.message, 'mensaje', contains('546'))));
    expect(n, 1);
    await expectLater(
        gateway.upload('transito-evidencias', 'objeto-sintético',
            Uint8List.fromList([1]), 'image/png'),
        throwsA(isA<StorageException>()));
    expect(n, 2);
    await client.dispose();
  });

  testWidgets(
      'configuración ausente permite elegir modo y falla sin iniciar Cloud',
      (tester) async {
    await tester.pumpWidget(const ModeSelection(
        configuration: OnlineConfiguration(url: '', publicKey: '')));
    expect(find.text('LOCAL · SQLite del dispositivo'), findsOneWidget);
    await tester.tap(find.text('DEFENSA EN LÍNEA · Requiere Internet'));
    await tester.pump();
    expect(find.textContaining('Configure SUPABASE_URL'), findsOneWidget);
  });
  test(
      'configuración rechaza claves privilegiadas y acepta solo publicable/anon',
      () {
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({
              'role': role
            })))}.signature';
    expect(
        OnlineConfiguration(
                url: 'https://example.invalid', publicKey: jwt('service_role'))
            .isValid,
        isFalse);
    expect(
        OnlineConfiguration(
                url: 'https://example.invalid', publicKey: jwt('anon'))
            .isValid,
        isTrue);
    expect(
        const OnlineConfiguration(
                url: 'https://example.invalid', publicKey: 'sb_secret_fake')
            .isValid,
        isFalse);
  });
  testWidgets('DI ONLINE arranca/restaura con BD bomba sin tocar SQLite',
      (tester) async {
    final gateway = FakeGateway(server, adminUid);
    await tester.pumpWidget(
        AccTransitoApp(remoteGateway: gateway, database: BombDatabase()));
    await tester.pumpAndSettle();
    expect(find.text('Inicio · DEFENSA EN LÍNEA'), findsOneWidget);
    expect(find.text('Gestionar policías'), findsNothing);
    gateway.offline = true;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo cargar el resumen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('listado relee al entrar, Actualizar y volver a primer plano',
      (tester) async {
    final adminGateway = FakeGateway(server, adminUid);
    await tester.pumpWidget(
        AccTransitoApp(remoteGateway: adminGateway, database: BombDatabase()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Consultar informes'), 300);
    await tester.ensureVisible(find.text('Consultar informes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consultar informes'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => reports.finalizeReport(input()));
    expect(find.text('2026-000001'), findsNothing);
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('2026-000001'), findsOneWidget);
    expect(find.text('Informes activos compartidos'), findsOneWidget);
    expect(find.textContaining('Autor: Grado ficticio'), findsOneWidget);
    expect(find.text('Inactivar'), findsNothing);
    await tester
        .runAsync(() => reports.finalizeReport(input(place: 'Segundo lugar')));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('2026-000002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiración retira la navegación de una sesión remota',
      (tester) async {
    final adminGateway = FakeGateway(server, adminUid);
    await tester.pumpWidget(
        AccTransitoApp(remoteGateway: adminGateway, database: BombDatabase()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Consultar informes'), 300);
    await tester.ensureVisible(find.text('Consultar informes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consultar informes'));
    await tester.pumpAndSettle();
    adminGateway.userId = null;
    adminGateway.events.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Ingreso · DEFENSA EN LÍNEA'), findsOneWidget);
    expect(find.text('Consultar informes'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('archivos privados serializados', () {
    late Directory temp;
    late String photo;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('transito_online_test_');
      final f = File('${temp.path}/sintetica.png');
      await f.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0]);
      photo = f.path;
      reports = OnlineReportRepository(a,
          fileService: OnlineFileService(a, cacheDirectory: () async => temp));
    });
    test('reserva/carga/verificación/vínculo y descarga de otro cliente',
        () async {
      await reports.finalizeReport(input(
          photos: [PhotoInput(ruta: photo, tipo: EvidencePhotoCategory.otra)],
          sketch: photo));
      expect(server.reservations.length, 2);
      expect(server.verifications, 2);
      expect(server.maxActiveFiles, 1);
      final admin = OnlineReportRepository(FakeGateway(server, adminUid),
          fileService: OnlineFileService(FakeGateway(server, adminUid),
              cacheDirectory: () async => temp));
      final detail = (await admin.findActiveReportDetail(1))!;
      expect(detail.fotografias.length, 1);
      expect(await File(detail.rutaCroquis!).exists(), isTrue);
      expect(server.maxActiveFiles, 1);
    });
    test('546 en verificador: no finaliza ni vuelve a invocar al recuperar',
        () async {
      a.verificationError = const OnlineException('546 sintético');
      await expectLater(
          reports.finalizeReport(input(photos: [
            PhotoInput(ruta: photo, tipo: EvidencePhotoCategory.otra)
          ])),
          throwsA(isA<OnlineException>()));
      await expectLater(
          reports.resumeFinalization(), throwsA(isA<OnlineException>()));
      expect(server.reports, isEmpty);
      expect(server.verifications, 1);
      expect(a.calls.where((c) => c['name'] == 'finalizar_informe'), isEmpty);
    });
    test('respuesta de finalización perdida con archivos no vuelve a verificar',
        () async {
      a.lostResponses = 2;
      await expectLater(
          reports.finalizeReport(input(photos: [
            PhotoInput(ruta: photo, tipo: EvidencePhotoCategory.otra)
          ])),
          throwsA(isA<OnlineException>()));
      expect(server.verifications, 1);
      expect(server.reports.length, 1);
      expect((await reports.resumeFinalization()).idInforme, 1);
      expect(server.verifications, 1);
      expect(server.reports.length, 1);
      final calls =
          a.calls.where((c) => c['name'] == 'finalizar_informe').toList();
      expect(calls.length, 3);
      expect(
          calls.every((c) => jsonEncode(c) == jsonEncode(calls.first)), isTrue);
    });

    test(
        'verificación confirmada con respuesta perdida se consulta sin reinvocarla',
        () async {
      a.loseVerificationResponse = true;
      await expectLater(
          reports.finalizeReport(input(photos: [
            PhotoInput(ruta: photo, tipo: EvidencePhotoCategory.otra)
          ])),
          throwsA(isA<TimeoutException>()));
      expect(server.verifications, 1);
      expect(server.reports, isEmpty);
      expect((await reports.resumeFinalization()).idInforme, 1);
      expect(server.verifications, 1);
    });

    test('límites y descripción no soportada no omiten archivos', () async {
      await expectLater(
          reports.finalizeReport(input(
              photos: List.generate(
                  13,
                  (_) => PhotoInput(
                      ruta: photo, tipo: EvidencePhotoCategory.otra)))),
          throwsA(isA<OnlineException>()));
      await expectLater(
          reports.finalizeReport(input(photos: [
            PhotoInput(
                ruta: photo,
                tipo: EvidencePhotoCategory.otra,
                descripcion: 'No perder')
          ])),
          throwsA(isA<OnlineException>()));
      expect(a.calls, isEmpty);
      await File(photo).writeAsBytes(Uint8List(5242881));
      await expectLater(
          reports.finalizeReport(input(photos: [
            PhotoInput(ruta: photo, tipo: EvidencePhotoCategory.otra)
          ])),
          throwsA(isA<OnlineException>()));
      expect(server.reports, isEmpty);
    });
    test('PDF se reserva/verifica/registra sin escrituras directas', () async {
      await reports.finalizeReport(input());
      final pdf = File('${temp.path}/sintetico.pdf');
      await pdf.writeAsString('%PDF-sintético');
      await reports.uploadPdf(1, pdf.path);
      await reports.uploadPdf(1, pdf.path);
      expect(server.archives.length, 1);
      expect(server.verifications, 1);
      expect(server.maxActiveFiles, 1);
    });
  });
}
