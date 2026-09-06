import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/repositories/report_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/report_format.dart';
import '../qr/institutional_qr_service.dart';

class DirectActionReportPdf {
  const DirectActionReportPdf({
    required this.fileName,
    required this.bytes,
    required this.qrPayload,
  });

  final String fileName;
  final Uint8List bytes;
  final InstitutionalQrPayload qrPayload;
}

class DirectActionReportPdfService {
  DirectActionReportPdfService({
    InstitutionalQrService qrService = const InstitutionalQrService(),
  }) : _qrService = qrService;

  final InstitutionalQrService _qrService;

  Future<DirectActionReportPdf> build({
    required ReportRecord report,
    required InstitutionalQrPolice owner,
  }) async {
    final qr = _qrService.generateForPolice(owner);
    final photos = await _loadPhotos(report.fotografias);
    final sketch = await _loadImage(report.rutaCroquis);
    final logoData = await rootBundle.load(AppConstants.logoAsset);
    final logo = pw.MemoryImage(logoData.buffer
        .asUint8List(logoData.offsetInBytes, logoData.lengthInBytes));
    final regular = await rootBundle.load('assets/fonts/roboto-regular.ttf');
    final bold = await rootBundle.load('assets/fonts/roboto-bold.ttf');
    final document = pw.Document(
      title: 'Informe de Acción Directa - ${report.numeroCaso}',
      author: owner.nombreCompleto,
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 36),
        maxPages: 1000,
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : _continuationHeader(report),
        footer: (context) => _buildFooter(context, report.numeroCaso),
        build: (context) => [
          _buildHeader(report, logo),
          ..._section(
            'Datos generales',
            _table([
              ['Número de caso', report.numeroCaso],
              ['EPI', report.epi],
              ['Naturaleza', report.naturaleza],
              ['Lugar', report.lugar],
              [
                'Fecha y hora de llegada',
                _formatDateTime(report.fechaHoraLlegada),
              ],
              [
                'Fecha y hora del hecho',
                _formatDateTime(report.fechaHoraHecho)
              ],
            ]),
          ),
          ..._section(
            'Denunciante',
            _table([
              ['Nombre', report.denuncianteNombre],
              ['Documento', report.denuncianteDocumento],
              ['Contacto', report.denuncianteContacto],
            ]),
          ),
          ..._section('Descripción del hecho', _paragraph(report.descripcion)),
          ..._section(
            'Condiciones y circunstancias',
            _table([
              ['Condiciones climáticas', report.condicionesClimaticas],
              ['Vehículos movidos', _boolText(report.vehiculosMovidos)],
              [
                'Protagonistas presentes',
                _boolText(report.protagonistasPresentes),
              ],
              ['Testigos', report.testigos],
              ['Efectos personales', report.efectosPersonales],
            ]),
          ),
          ..._buildDrivers(report.conductores),
          ..._buildVehicles(report.vehiculos, report.conductores),
          ..._buildPeople(report.personas),
          ..._section(
            'Ubicación del hecho',
            _table([
              ['Lugar textual', report.lugar],
              ['Latitud', report.latitud?.toStringAsFixed(6)],
              ['Longitud', report.longitud?.toStringAsFixed(6)],
            ]),
          ),
          ..._buildSketch(sketch, report.rutaCroquis),
          ..._buildPhotos(photos),
          ..._buildPoliceAndQr(owner, qr.payload.toStructuredText()),
        ],
      ),
    );

    return DirectActionReportPdf(
      fileName: buildFileName(report: report, owner: owner),
      bytes: await document.save(),
      qrPayload: qr.payload,
    );
  }

  String buildFileName({
    required ReportRecord report,
    required InstitutionalQrPolice owner,
  }) {
    return [
          _safePart(report.numeroCaso),
          _safePart(owner.grado),
          _safePart(_lastName(owner.nombreCompleto)),
          _safePart(_firstName(owner.nombreCompleto)),
        ].join('_') +
        '.pdf';
  }

  pw.Widget _buildHeader(ReportRecord report, pw.MemoryImage logo) {
    return pw
        .Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(children: [
        pw.Image(logo, width: 64, height: 64, fit: pw.BoxFit.contain),
        pw.SizedBox(width: 18),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text('DIRECCIÓN DEPARTAMENTAL DE TRÁNSITO',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('TRANSPORTE Y SEGURIDAD VIAL',
                  style: const pw.TextStyle(fontSize: 10)),
            ])),
      ]),
      pw.SizedBox(height: 16),
      pw.Divider(thickness: 1.2, color: PdfColors.grey800),
      pw.SizedBox(height: 10),
      pw.Text('INFORME DE ACCIÓN DIRECTA',
          style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('CASO Nº ${report.numeroCaso}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Text('Finalizado · ${report.isActive ? 'Activo' : 'Inactivo'}',
            style: const pw.TextStyle(fontSize: 10)),
      ]),
      pw.SizedBox(height: 4),
    ]);
  }

  pw.Widget _continuationHeader(ReportRecord report) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('INFORME DE ACCIÓN DIRECTA',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Caso ${report.numeroCaso}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700)),
            ]),
      );

  pw.Widget _buildFooter(pw.Context context, String caseNumber) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Caso $caseNumber',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
              pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ]),
      );

  List<pw.Widget> _buildDrivers(List<DriverRecord> drivers) {
    return _section(
      'Conductores',
      drivers.isEmpty
          ? _emptyText('No se registraron conductores.')
          : pw.Column(
              children: [
                for (final (index, driver) in drivers.indexed)
                  ..._recordBlock('Conductor ${index + 1}', [
                    ['Nombre completo', driver.nombreCompleto],
                    ['Edad', driver.edad?.toString()],
                    ['Licencia', driver.licencia],
                    ['Categoría', driver.categoria],
                    ['Domicilio', driver.domicilio],
                    ['Zona', driver.zona],
                    ['Contactos', driver.contactos],
                    ['Condición de entrega', driver.condicionEntrega],
                  ]),
              ],
            ),
    );
  }

  List<pw.Widget> _buildVehicles(
      List<VehicleRecord> vehicles, List<DriverRecord> drivers) {
    final driverNames = {
      for (final driver in drivers) driver.idConductor: driver.nombreCompleto
    };
    return _section(
      'Vehículos',
      vehicles.isEmpty
          ? _emptyText('No se registraron vehículos.')
          : pw.Column(
              children: [
                for (final (index, vehicle) in vehicles.indexed)
                  ..._recordBlock('Vehículo ${index + 1}', [
                    ['Placa', vehicle.placa],
                    ['Marca', vehicle.marca],
                    ['Color', vehicle.color],
                    ['Tipo', vehicle.tipo],
                    ['Servicio', vehicle.servicio],
                    [
                      'Conductor relacionado',
                      driverNames[vehicle.idConductor],
                    ],
                  ]),
              ],
            ),
    );
  }

  List<pw.Widget> _buildPeople(List<PersonRecord> people) {
    return _section(
      'Personas involucradas',
      people.isEmpty
          ? _emptyText('No se registraron personas involucradas.')
          : pw.Column(
              children: [
                for (final (index, person) in people.indexed)
                  ..._recordBlock('Persona ${index + 1}', [
                    ['Nombre', person.nombre],
                    ['Tipo', _personType(person.tipo)],
                    ['Edad', person.edad?.toString()],
                    ['Lugar de evacuación', person.lugarEvacuacion],
                  ]),
              ],
            ),
    );
  }

  List<pw.Widget> _buildSketch(_LoadedImage? sketch, String? path) => _section(
        'Croquis cartográfico',
        sketch == null
            ? _emptyText(_hasText(path)
                ? 'El croquis registrado no está disponible en este dispositivo.'
                : 'No se registró un croquis.')
            : pw.Container(
                width: double.infinity,
                height: 280,
                decoration: pw.BoxDecoration(
                    border:
                        pw.Border.all(color: PdfColors.grey400, width: 0.5)),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Image(sketch.image, fit: pw.BoxFit.contain)),
      );

  List<pw.Widget> _buildPhotos(List<_LoadedPhoto> photos) => _section(
        'Registro fotográfico',
        photos.isEmpty
            ? _emptyText('No se registraron fotografías.')
            : pw.Column(children: [
                for (var index = 0; index < photos.length; index += 2) ...[
                  pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(child: _photoTile(photos[index])),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                                child: index + 1 < photos.length
                                    ? _photoTile(photos[index + 1])
                                    : pw.SizedBox()),
                          ])),
                  for (final photo in photos.skip(index).take(2))
                    if (photo.description != null) ...[
                      _paragraph('${photo.label}: ${photo.description}'),
                      pw.SizedBox(height: 10),
                    ],
                ],
              ]),
      );

  List<pw.Widget> _buildPoliceAndQr(
      InstitutionalQrPolice owner, String payload) {
    final content = <pw.Widget>[
      ..._section(
          'Funcionario responsable',
          _table([
            ['Nombre completo', owner.nombreCompleto],
            ['Grado', owner.grado],
            ['Número de placa', owner.numeroPlaca],
            ['Unidad', owner.unidad],
          ])).skip(1),
      pw.SizedBox(height: 18),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Column(children: [
          pw.Container(
              width: 140,
              height: 140,
              color: PdfColors.white,
              padding: const pw.EdgeInsets.all(10),
              child: pw.BarcodeWidget(
                  data: payload,
                  barcode: pw.Barcode.qrCode(),
                  drawText: false)),
          pw.Text('QR institucional', style: const pw.TextStyle(fontSize: 9)),
        ]),
        pw.SizedBox(width: 40),
        pw.Expanded(
            child: pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(children: [
                  pw.Divider(color: PdfColors.grey700, thickness: 0.6),
                  pw.SizedBox(height: 6),
                  pw.Text('Firma del policía que realizó\nla Acción Directa',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10)),
                ]))),
      ]),
    ];
    if ([owner.nombreCompleto, owner.grado, owner.numeroPlaca, owner.unidad]
        .every((value) => value.length < 120)) {
      return [
        pw.Inseparable(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: content))
      ];
    }
    return [pw.NewPage(freeSpace: 110), ...content];
  }

  pw.Widget _photoTile(_LoadedPhoto photo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 172,
            width: double.infinity,
            child: photo.image == null
                ? pw.Center(child: _emptyText('Fotografía no disponible'))
                : pw.Image(photo.image!.image, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            photo.label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _section(String title, pw.Widget child) => [
        // Solo reservar el comienzo; tablas y narrativas fluyen entre páginas.
        pw.NewPage(freeSpace: _sectionSpace(title, child)),
        pw.SizedBox(height: 18),
        pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(bottom: 7),
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    bottom:
                        pw.BorderSide(color: PdfColors.grey600, width: 0.7))),
            child: pw.Text(title.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.7))),
        pw.SizedBox(height: 9),
        if (child is pw.Column) ...child.children else child,
      ];

  double _sectionSpace(String title, pw.Widget child) => switch (title) {
        'Croquis cartográfico' when child is pw.Container => 330,
        'Registro fotográfico' when child is pw.Column => 270,
        'Conductores' when child is pw.Column => 290,
        'Vehículos' when child is pw.Column => 250,
        'Personas involucradas' when child is pw.Column => 200,
        _ => 110,
      };

  List<pw.Widget> _recordBlock(String title, List<List<String?>> rows) {
    final heading = pw.Text(title,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold));
    final content = [
      heading,
      pw.SizedBox(height: 5),
      _table(rows),
      pw.SizedBox(height: 12)
    ];
    // Mantener registros normales juntos. Los extensos pueden continuar
    // en otra página y cada fila conserva su etiqueta.
    if (rows.every((row) => (row[1]?.length ?? 0) < 120)) {
      return [
        pw.Inseparable(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: content))
      ];
    }
    return [pw.NewPage(freeSpace: 100), ...content];
  }

  pw.Widget _table(List<List<String?>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(2),
      },
      children: _flowRows(rows)
          .map(
            (row) => pw.TableRow(
              children: [
                _cell(row[0] ?? '', isHeader: true),
                _cell(_value(row.length > 1 ? row[1] : null)),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      color: isHeader ? PdfColors.grey100 : null,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _paragraph(String? text) {
    return pw.Text(
      _value(text),
      overflow: pw.TextOverflow.span,
      style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
    );
  }

  pw.Widget _emptyText(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
    );
  }

  Future<List<_LoadedPhoto>> _loadPhotos(List<PhotoRecord> photos) async {
    final loaded = <_LoadedPhoto>[];
    final cache = <String, Future<_LoadedImage?>>{};
    for (final (index, photo) in photos.indexed) {
      final image =
          await cache.putIfAbsent(photo.ruta, () => _loadImage(photo.ruta));
      loaded.add(
        _LoadedPhoto(
          image: image,
          label: 'Fotografía ${index + 1}: ${photo.tipo.label}',
          description: ReportFormat.photoDescription(photo.descripcion),
        ),
      );
    }
    return loaded;
  }

  Future<_LoadedImage?> _loadImage(String? path) async {
    if (!_hasText(path)) {
      return null;
    }
    try {
      final file = File(path!);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return _LoadedImage(pw.MemoryImage(bytes));
    } catch (_) {
      return null;
    }
  }

  static String _formatDateTime(DateTime? value) =>
      ReportFormat.dateTime(value);
  static String _boolText(bool? value) => ReportFormat.boolean(value);
  static String _personType(String value) => ReportFormat.personType(value);
  static String _value(String? value) => ReportFormat.value(value);
  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  // Una fila de Table no se divide entre páginas. Fragmentar valores extensos
  // mantiene todos sus caracteres sin encerrar la relación en un bloque rígido.
  Iterable<List<String?>> _flowRows(List<List<String?>> rows) sync* {
    for (final row in rows) {
      final value = _value(row[1]);
      var offset = 0;
      while (offset < value.length) {
        var end = (offset + 320).clamp(0, value.length);
        if (end < value.length) {
          final space = value.lastIndexOf(' ', end);
          if (space > offset + 160) end = space + 1;
        }
        yield [
          offset == 0 ? row[0] : '${row[0]} (continuación)',
          value.substring(offset, end)
        ];
        offset = end;
      }
    }
  }

  static String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  static String _lastName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.length < 2 ? fullName : parts.last;
  }

  static String _safePart(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]'), '');
  }
}

class _LoadedImage {
  const _LoadedImage(this.image);

  final pw.MemoryImage image;
}

class _LoadedPhoto {
  const _LoadedPhoto({
    required this.image,
    required this.label,
    this.description,
  });

  final _LoadedImage? image;
  final String label;
  final String? description;
}
