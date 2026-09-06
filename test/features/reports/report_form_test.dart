import 'dart:async';

import 'package:app_acc_transito/data/database/app_database.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/features/auth/domain/app_role.dart';
import 'package:app_acc_transito/features/auth/domain/authenticated_user.dart';
import 'package:app_acc_transito/features/reports/application/report_controller.dart';
import 'package:app_acc_transito/features/reports/report_list_page.dart';
import 'package:app_acc_transito/services/external_apps/external_maps_service.dart';
import 'package:app_acc_transito/services/geolocation/geolocation_service.dart';
import 'package:app_acc_transito/services/maps/map_snapshot_service.dart';
import 'package:app_acc_transito/services/media/evidence_media_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _actor = AuthenticatedUser(
    idUsuario: 1,
    username: 'policia',
    role: AppRole.police,
    policeProfile: PoliceProfile(
        idPolicia: 1,
        numeroPlaca: '01',
        grado: 'Sgto.',
        nombres: 'José',
        apellidos: 'Muñoz Peña',
        unidad: 'Tránsito',
        sigla: 'UT',
        ci: '01'));

void main() {
  testWidgets(
      'wizard conserva datos, bloquea salida al guardar y vuelve al finalizar',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _PendingController();
    await _open(tester, controller);
    await _fill(tester, 'EPI / Estación Policial Integral', 'EPI Central');
    await _date(tester, 'Fecha y hora de llegada');
    await _date(tester, 'Fecha y hora del hecho');
    await _fill(tester, 'Naturaleza', 'Colisión');
    await _fill(tester, 'Lugar', 'Ubicación de José Muñoz Peña');
    await _tap(tester, 'Siguiente');
    await _fill(tester, 'Denunciante', 'José Muñoz Peña');
    await _fill(tester, 'Contacto del denunciante', 'No existe');
    await _tap(tester, 'Siguiente');
    await _fill(tester, 'Descripción', 'Descripción del vehículo');
    await _fill(tester, 'Condiciones climáticas', 'Despejado');
    for (final index in [0, 1]) {
      final yes = find.text('Sí').at(index);
      await tester.ensureVisible(yes);
      await tester.tap(yes);
      await tester.pumpAndSettle();
    }
    await _fill(tester, 'Testigos', 'No existe');
    await _fill(tester, 'Efectos personales', 'No aplica');
    await _tap(tester, 'Siguiente');
    await _fill(tester, 'Latitud', 'NaN');
    await _tap(tester, 'Siguiente');
    expect(find.text('Ingrese un valor entre -90 y 90.'), findsOneWidget);
    await _fill(tester, 'Latitud', '');
    await _tap(tester, 'Siguiente');
    await _tap(tester, 'Siguiente');
    await _tap(tester, 'Finalizar informe');
    expect(controller.calls, 1);
    expect(controller.submitted!.denuncianteNombre, 'José Muñoz Peña');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Cancelar informe'), findsNothing);
    expect(find.byType(DirectActionReportFormPage), findsOneWidget);
    controller.completion.complete(const FinalizedReport(
        idInforme: 1,
        gestion: 2026,
        correlativo: 1,
        numeroCaso: '2026-000001'));
    await tester.pumpAndSettle();
    expect(find.byType(DirectActionReportFormPage), findsNothing);
    expect(find.text('Abrir formulario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('volver con texto sin guardar pide confirmación y descarta',
      (tester) async {
    await _open(tester, _PendingController());
    await _fill(
        tester, 'EPI / Estación Policial Integral', 'Texto sin guardar');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Cancelar informe'), findsOneWidget);
    await _tap(tester, 'Descartar');
    expect(find.byType(DirectActionReportFormPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(WidgetTester tester, ReportController controller) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('es', 'BO'),
    supportedLocales: const [Locale('es', 'BO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Builder(
        builder: (context) => Scaffold(
                body: TextButton(
              child: const Text('Abrir formulario'),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => DirectActionReportFormPage(
                            controller: controller,
                            actor: _actor,
                            geolocationService: const GeolocationService(),
                            mapSnapshotService: const MapSnapshotService(),
                            externalMapsService: const ExternalMapsService(),
                            evidenceMediaService: EvidenceMediaService(),
                          ))),
            ))),
  ));
  await _tap(tester, 'Abrir formulario');
}

Future<void> _fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text(text), 250,
        scrollable: find.byType(Scrollable).first);
  }
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _date(WidgetTester tester, String label) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  final ok = MaterialLocalizations.of(tester.element(field)).okButtonLabel;
  await tester.tap(field);
  await tester.pumpAndSettle();
  await _tap(tester, ok);
  await _tap(tester, ok);
}

class _PendingController extends ReportController {
  _PendingController() : super(repository: ReportRepository(AppDatabase()));
  final completion = Completer<FinalizedReport>();
  int calls = 0;
  DirectActionReportDraft? submitted;
  @override
  Future<FinalizedReport> finalize(
      {required AuthenticatedUser actor,
      required DirectActionReportDraft draft,
      DateTime? now,
      PersistPhotosForCase? persistPhotosForCase,
      CleanupPhotos? cleanupPersistedPhotos}) {
    calls++;
    submitted = draft;
    return completion.future;
  }
}
