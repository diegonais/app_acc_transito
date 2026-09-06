import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_acc_transito/app/theme/app_theme.dart';
import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/features/reports/report_detail_content.dart';
import 'package:app_acc_transito/features/reports/widgets/report_detail_widgets.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
import 'package:app_acc_transito/services/qr/institutional_qr_service.dart';
import 'package:app_acc_transito/shared/report_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const owner = InstitutionalQrPolice(
    nombreCompleto: 'José Muñoz Peña',
    grado: 'Sgto.',
    numeroPlaca: 'PL-Ñ01',
    unidad: 'División de Tránsito');

ReportRecord fixture({bool full = false}) => ReportRecord(
      idInforme: 1,
      idPolicia: 1,
      gestion: 2026,
      correlativo: 1,
      numeroCaso: '2026-000001',
      epi: 'Miraflores',
      estado: 1,
      fechaCreacion: DateTime(2026, 9, 6),
      fechaModificacion: DateTime(2026, 9, 6),
      fechaHoraHecho: DateTime(2026, 9, 6, 0, 14),
      fechaHoraLlegada: DateTime(2026, 9, 6, 0, 25),
      naturaleza: 'Colisión',
      lugar: 'Av. Busch, intersección con calle Villalobos',
      denuncianteNombre: 'María Quispe',
      denuncianteDocumento: 'CI-123',
      descripcion: full
          ? 'El funcionario acudió al lugar del hecho. Se registraron las condiciones y los vehículos presentes.\n' *
              12
          : null,
      condicionesClimaticas: 'Despejado',
      vehiculosMovidos: false,
      protagonistasPresentes: true,
      latitud: full ? -16.5 : null,
      longitud: full ? -68.1 : null,
      conductores: full
          ? List.generate(
              2,
              (i) => DriverRecord(
                  idConductor: i + 1,
                  nombreCompleto: 'Conductor José ${i + 1}',
                  edad: 31,
                  licencia: 'A-123',
                  categoria: 'A',
                  domicilio: 'Calle de la ciudad',
                  zona: 'Norte',
                  contactos: '70000001',
                  condicionEntrega: 'Entregado a familiar'))
          : [],
      vehiculos: full
          ? List.generate(
              2,
              (i) => VehicleRecord(
                  idVehiculo: i + 1,
                  idConductor: i + 1,
                  placa: 'ABC-${i + 1}',
                  marca: 'Toyota',
                  color: 'Blanco',
                  tipo: 'Automóvil',
                  servicio: 'Particular'))
          : [],
      personas: full
          ? List.generate(
              2,
              (i) => PersonRecord(
                  idPersona: i + 1,
                  nombre: 'María Peña ${i + 1}',
                  tipo: i == 0 ? 'HERIDO' : 'FALLECIDO',
                  edad: 24,
                  lugarEvacuacion: 'Hospital municipal'))
          : [],
      rutaCroquis: full ? 'missing/private/croquis.png' : null,
      fotografias: full
          ? const [
              PhotoRecord(
                  idFotografia: 1,
                  ruta: 'missing/private/photo.jpg',
                  tipo: EvidencePhotoCategory.panoramica,
                  descripcion: 'image/jpeg')
            ]
          : [],
    );

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<void> pump(WidgetTester tester,
      {bool full = false, double scale = 1, VoidCallback? onPdf}) async {
    await tester.pumpWidget(MaterialApp(
        // En Android estos estilos usan Roboto del sistema. El motor de tests
        // usa Ahem por defecto si el estilo no especifica familia.
        theme: AppTheme.light.copyWith(
          appBarTheme: AppTheme.light.appBarTheme.copyWith(
              titleTextStyle: AppTheme.light.appBarTheme.titleTextStyle
                  ?.copyWith(fontFamily: 'Roboto')),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: AppTheme.light.elevatedButtonTheme.style?.copyWith(
                  textStyle: const WidgetStatePropertyAll(TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)))),
        ),
        home: MediaQuery(
            data: MediaQueryData(
                size: tester.view.physicalSize,
                textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
                key: const ValueKey('review'),
                child: Scaffold(
                    appBar: AppBar(title: const Text('Detalle de informe')),
                    body: ReportDetailContent(
                        report: fixture(full: full),
                        owner: Future.value(owner),
                        onPdf: onPdf ?? () {},
                        onMaps: () {}))))));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300,
        maxScrolls: 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.2);
    await tester.pumpAndSettle();
    for (var i = 0; i < 8 && finder.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  }

  test(
      'presentación conserva español y oculta solamente metadatos MIME heredados',
      () {
    expect(ReportFormat.value('  '), 'No registrado');
    expect(ReportFormat.boolean(false), 'No');
    expect(ReportFormat.boolean(true), 'Sí');
    expect(ReportFormat.boolean(null), 'No registrado');
    expect(ReportFormat.personType('FALLECIDO'), 'Fallecido');
    expect(ReportFormat.photoDescription('image/jpeg'), isNull);
    expect(ReportFormat.photoDescription('Placa dañada, ñ y á'),
        'Placa dañada, ñ y á');
  });

  testWidgets('caso, estado, acción PDF y todas las secciones vacías',
      (tester) async {
    tester.view.reset();
    var opened = false;
    await pump(tester, onPdf: () => opened = true);
    expect(find.text('2026-000001'), findsOneWidget);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    await tester.tap(find.text('Ver informe PDF'));
    expect(opened, isTrue);
    for (final text in [
      'No se registraron conductores.',
      'No se registraron vehículos.',
      'No se registraron personas involucradas.',
      'No se registró un croquis.',
      'No se registraron fotografías.',
      'QR institucional'
    ]) {
      await reveal(tester, find.text(text));
    }
    expect(find.byType(InstitutionalQrView), findsOneWidget);
    expect(find.text('PL-Ñ01'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0, 800.0]) {
    testWidgets(
        'consulta completa a $width px con texto ampliado sin cortes de layout',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, full: true, scale: 2);
      await reveal(tester, find.text('Conductor José 2'));
      expect(find.text('Entregado a familiar'), findsWidgets);
      await reveal(tester, find.text('Placa ABC-2'));
      await reveal(tester, find.text('Persona 2 · Fallecido'));
      await reveal(tester, find.text('-16.500000'));
      await reveal(tester, find.text('Fotografía 1 · Panorámica'));
      expect(find.textContaining('missing/private'), findsNothing);
      expect(find.text('image/jpeg'), findsNothing);
      await tester.tap(find.text('Fotografía 1 · Panorámica'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportImageViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.runAsync(() async {
        await File('missing/private/photo.jpg').exists();
      });
      await tester.pumpAndSettle();
      expect(find.text('La imagen no está disponible en este dispositivo.'),
          findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('QR institucional'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('croquis se amplía conservando proporción y vista de consulta',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
            body: SingleChildScrollView(
                child: ReportImageCard(
                    path: 'assets/images/logo_transito.png',
                    title: 'Croquis cartográfico',
                    isSketch: true)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tocar para ampliar'));
    await tester.tap(find.text('Tocar para ampliar'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportImageViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('captura reproducible de cabecera para revisión visual',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, full: true);
    const output = String.fromEnvironment('UI_REVIEW_OUTPUT');
    if (output.isNotEmpty) {
      Future<void> capture(String path) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('review')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(path).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture(output);
      await reveal(tester, find.text('Conductor José 1'));
      await capture(output.replaceFirst('.png', '-conductor.png'));
      await reveal(tester, find.text('Fotografía 1 · Panorámica'));
      await tester.runAsync(() async {
        await File('missing/private/photo.jpg').exists();
      });
      await tester.pumpAndSettle();
      await capture(output.replaceFirst('.png', '-fotografia.png'));
      await reveal(tester, find.text('QR institucional'));
      await capture(output.replaceFirst('.png', '-qr.png'));
    }
    expect(tester.takeException(), isNull);
  });
}
