import 'dart:io';

import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/services/pdf/direct_action_report_pdf_service.dart';
import 'package:app_acc_transito/services/qr/institutional_qr_service.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('report_pdf_test_');
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('integra el QR institucional en el PDF generado', () async {
    final report = _report(
      naturaleza: 'Colisión',
      lugar: 'Av. Principal',
    );
    const owner = InstitutionalQrPolice(
      nombreCompleto: 'Ana Quispe',
      grado: 'Sgto.',
      numeroPlaca: 'PL-123',
      unidad: 'Tránsito',
    );

    final pdf = await DirectActionReportPdfService().build(
      report: report,
      owner: owner,
    );

    expect(pdf.bytes, isNotEmpty);
    expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
    expect(pdf.fileName, '2026-000001_Sgto_Quispe_Ana.pdf');
    expect(pdf.qrPayload.toStructuredText(), contains('Ana Quispe'));
    expect(pdf.qrPayload.toStructuredText(), contains('PL-123'));
  });

  test('normaliza el nombre del PDF sin caracteres inseguros', () {
    final report = _report(
      numeroCaso: '2026-000012',
      correlativo: 12,
    );
    const owner = InstitutionalQrPolice(
      nombreCompleto: 'Ana Maria Quispe/Rojas',
      grado: 'Sgto. 1ro',
      numeroPlaca: 'PL-123',
      unidad: 'Tránsito',
    );

    final fileName = DirectActionReportPdfService().buildFileName(
      report: report,
      owner: owner,
    );

    expect(fileName, '2026-000012_Sgto_1ro_QuispeRojas_Ana.pdf');
    expect(fileName, isNot(contains('/')));
    expect(fileName, endsWith('.pdf'));
  });

  test('genera PDF completo con relaciones, coordenadas, foto y croquis',
      () async {
    final image = await _writePng(sandbox, 'evidencia.png');
    final sketch = await _writePng(sandbox, 'croquis.png');
    final report = _report(
      descripcion: 'Descripción extensa del hecho ' * 30,
      denuncianteNombre: 'Rosa Lima',
      denuncianteDocumento: 'CI-55',
      denuncianteContacto: '70000000',
      latitud: -17.783327,
      longitud: -63.182140,
      rutaCroquis: sketch.path,
      conductores: const [
        DriverRecord(
          idConductor: 1,
          nombreCompleto: 'Juan Perez',
          edad: 34,
          licencia: 'LP-123',
          categoria: 'A',
          domicilio: 'Barrio Norte',
          zona: 'Norte',
          contactos: '70000001',
        ),
      ],
      vehiculos: const [
        VehicleRecord(
          idVehiculo: 1,
          idConductor: 1,
          placa: '123ABC',
          marca: 'Toyota',
          color: 'Blanco',
          tipo: 'Vagoneta',
          servicio: 'Particular',
        ),
      ],
      personas: const [
        PersonRecord(
          idPersona: 1,
          nombre: 'Maria Rojas',
          tipo: 'HERIDO',
          edad: 30,
          lugarEvacuacion: 'Hospital',
        ),
      ],
      fotografias: [
        PhotoRecord(
          idFotografia: 1,
          ruta: image.path,
          tipo: EvidencePhotoCategory.panoramica,
          descripcion: 'image/png',
        ),
      ],
    );

    final pdf = await DirectActionReportPdfService().build(
      report: report,
      owner: _owner,
    );

    expect(pdf.bytes, isNotEmpty);
    expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
    expect(pdf.qrPayload.toStructuredText(), contains('PL-123'));
    await _reviewOutput(pdf, 'completo');
  });

  test('genera con listas vacías y multiples relaciones', () async {
    final empty = await DirectActionReportPdfService().build(
      report: _report(
        conductores: const [],
        vehiculos: const [],
        personas: const [],
      ),
      owner: _owner,
    );
    final multiple = await DirectActionReportPdfService().build(
      report: _report(
        conductores: const [
          DriverRecord(idConductor: 1, nombreCompleto: 'Juan Perez'),
          DriverRecord(idConductor: 2, nombreCompleto: 'Luis Roca'),
        ],
        vehiculos: const [
          VehicleRecord(idVehiculo: 1, placa: '123ABC'),
          VehicleRecord(idVehiculo: 2, placa: '456DEF'),
        ],
        personas: const [
          PersonRecord(idPersona: 1, nombre: 'Ana Soliz', tipo: 'HERIDO'),
          PersonRecord(idPersona: 2, nombre: 'Rosa Lima', tipo: 'FALLECIDO'),
        ],
      ),
      owner: _owner,
    );

    expect(String.fromCharCodes(empty.bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(multiple.bytes.take(5)), '%PDF-');
    await _reviewOutput(empty, 'vacio');
    await _reviewOutput(multiple, 'relaciones');
  });

  test('omite fotografía y croquis faltantes sin lanzar excepcion', () async {
    final report = _report(
      rutaCroquis: '${sandbox.path}/croquis_faltante.png',
      fotografias: [
        PhotoRecord(
          idFotografia: 1,
          ruta: '${sandbox.path}/foto_faltante.jpg',
          tipo: EvidencePhotoCategory.otra,
        ),
      ],
    );

    final pdf = await DirectActionReportPdfService().build(
      report: report,
      owner: _owner,
    );

    expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
    await _reviewOutput(pdf, 'faltantes');
  });

  test('genera muchas páginas con texto español, relaciones y fotos', () async {
    final image = await _writePng(sandbox, 'foto.png');
    final pdf = await DirectActionReportPdfService().build(
      report: _report(
        descripcion:
            'José Muñoz Peña. Información, Descripción, Ubicación, Acción, Vehículo. ' *
                180,
        conductores: List.generate(
            20,
            (i) => DriverRecord(
                idConductor: i + 1,
                nombreCompleto: 'Conductor José Muñoz Peña ${i + 1}')),
        fotografias: List.generate(
            14,
            (i) => PhotoRecord(
                idFotografia: i + 1,
                ruta: image.path,
                tipo: EvidencePhotoCategory.panoramica)),
      ),
      owner: const InstitutionalQrPolice(
          nombreCompleto: 'José Muñoz Peña',
          grado: 'Sgto.',
          numeroPlaca: 'PL-Ñ01',
          unidad: 'División de Tránsito'),
    );
    expect(pdf.qrPayload.nombreCompleto, 'José Muñoz Peña');
    expect(pdf.fileName, contains('Peña_José'));
    expect(String.fromCharCodes(pdf.bytes), contains('/FontFile2'));
    const output = String.fromEnvironment('PDF_REVIEW_OUTPUT');
    if (output.isNotEmpty) await File(output).writeAsBytes(pdf.bytes);
  });

  test('omite imágenes corruptas sin impedir el PDF', () async {
    final file = File('${sandbox.path}/corrupta.jpg');
    await file.writeAsBytes([1, 2, 3, 4]);
    final pdf = await DirectActionReportPdfService().build(
        report: _report(rutaCroquis: file.path, fotografias: [
          PhotoRecord(
              idFotografia: 1,
              ruta: file.path,
              tipo: EvidencePhotoCategory.otra)
        ]),
        owner: _owner);
    expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
  });

  test('pagina campos relacionados y etiquetas extensas sin perder evidencia',
      () async {
    final image = await _writePng(sandbox, 'foto_etiquetada.png');
    final pdf = await DirectActionReportPdfService().build(
        report: _report(
          naturaleza: null,
          lugar: null,
          descripcion: null,
          denuncianteNombre: null,
          denuncianteContacto: null,
          conductores: [
            DriverRecord(
                idConductor: 1,
                nombreCompleto: 'José Muñoz',
                domicilio:
                    'Domicilio extenso con referencia a la ubicación. ' * 100,
                condicionEntrega: 'FIN CONDICIÓN')
          ],
          vehiculos: const [
            VehicleRecord(idVehiculo: 1, idConductor: 1, placa: 'Ñ-123')
          ],
          personas: [
            PersonRecord(
                idPersona: 1,
                nombre: 'María Peña',
                tipo: 'HERIDO',
                lugarEvacuacion: 'Información de evacuación. ' * 100)
          ],
          fotografias: [
            PhotoRecord(
                idFotografia: 1,
                ruta: image.path,
                tipo: EvidencePhotoCategory.otra,
                descripcion:
                    '${'Etiqueta con información de la fotografía. ' * 100}FIN ETIQUETA')
          ],
        ),
        owner: _owner);
    expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
    await _reviewOutput(pdf, 'campos-largos');
  });
}

Future<void> _reviewOutput(DirectActionReportPdf pdf, String suffix) async {
  const output = String.fromEnvironment('PDF_REVIEW_OUTPUT');
  if (output.isNotEmpty) {
    await File(output.replaceFirst(RegExp(r'\.pdf$'), '-$suffix.pdf'))
        .writeAsBytes(pdf.bytes);
  }
}

const _owner = InstitutionalQrPolice(
  nombreCompleto: 'Ana Quispe',
  grado: 'Sgto.',
  numeroPlaca: 'PL-123',
  unidad: 'Tránsito',
);

ReportRecord _report({
  int correlativo = 1,
  String numeroCaso = '2026-000001',
  String? naturaleza = 'Colisión',
  String? lugar = 'Av. Principal',
  String? descripcion = 'Descripción del hecho',
  String? denuncianteNombre = 'No existe',
  String? denuncianteDocumento,
  String? denuncianteContacto = 'No existe',
  double? latitud,
  double? longitud,
  String? rutaCroquis,
  List<DriverRecord> conductores = const [],
  List<VehicleRecord> vehiculos = const [],
  List<PersonRecord> personas = const [],
  List<PhotoRecord> fotografias = const [],
}) {
  return ReportRecord(
    idInforme: 1,
    idPolicia: 10,
    gestion: 2026,
    correlativo: correlativo,
    numeroCaso: numeroCaso,
    epi: 'EPI Norte',
    estado: 1,
    fechaCreacion: DateTime.utc(2026),
    fechaModificacion: DateTime.utc(2026),
    fechaHoraLlegada: DateTime.utc(2026, 9, 5, 13, 25),
    fechaHoraHecho: DateTime.utc(2026, 9, 5, 13),
    naturaleza: naturaleza,
    lugar: lugar,
    denuncianteNombre: denuncianteNombre,
    denuncianteDocumento: denuncianteDocumento,
    denuncianteContacto: denuncianteContacto,
    descripcion: descripcion,
    condicionesClimaticas: 'Despejado',
    vehiculosMovidos: false,
    protagonistasPresentes: true,
    testigos: 'No existe',
    efectosPersonales: 'No aplica',
    latitud: latitud,
    longitud: longitud,
    rutaCroquis: rutaCroquis,
    conductores: conductores,
    vehiculos: vehiculos,
    personas: personas,
    fotografias: fotografias,
  );
}

Future<File> _writePng(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  final bytes = await File('assets/images/logo_transito.png').readAsBytes();
  await file.writeAsBytes(bytes);
  return file;
}
