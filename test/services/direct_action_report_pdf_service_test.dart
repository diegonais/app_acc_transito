import 'dart:io';

import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/services/pdf/direct_action_report_pdf_service.dart';
import 'package:app_acc_transito/services/qr/institutional_qr_service.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      naturaleza: 'Colision',
      lugar: 'Av. Principal',
    );
    const owner = InstitutionalQrPolice(
      nombreCompleto: 'Ana Quispe',
      grado: 'Sgto.',
      numeroPlaca: 'PL-123',
      unidad: 'Transito',
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
      unidad: 'Transito',
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
      descripcion: 'Descripcion extensa del hecho ' * 30,
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
  });

  test('genera con listas vacias y multiples relaciones', () async {
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
  });

  test('omite fotografia y croquis faltantes sin lanzar excepcion', () async {
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
  });
}

const _owner = InstitutionalQrPolice(
  nombreCompleto: 'Ana Quispe',
  grado: 'Sgto.',
  numeroPlaca: 'PL-123',
  unidad: 'Transito',
);

ReportRecord _report({
  int correlativo = 1,
  String numeroCaso = '2026-000001',
  String? naturaleza = 'Colision',
  String? lugar = 'Av. Principal',
  String? descripcion = 'Descripcion del hecho',
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
