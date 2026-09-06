import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/repositories/report_repository.dart';
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
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        footer: _buildFooter,
        build: (context) => [
          _buildHeader(report),
          _section(
            'Datos generales',
            _table([
              ['Numero de caso', report.numeroCaso],
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
          _section('Descripcion del hecho', _paragraph(report.descripcion)),
          _section(
            'Denunciante',
            _table([
              ['Nombre', report.denuncianteNombre],
              ['Documento', report.denuncianteDocumento],
              ['Contacto', report.denuncianteContacto],
            ]),
          ),
          _section(
            'Condiciones y circunstancias',
            _table([
              ['Condiciones climaticas', report.condicionesClimaticas],
              ['Vehiculos movidos', _boolText(report.vehiculosMovidos)],
              [
                'Protagonistas presentes',
                _boolText(report.protagonistasPresentes),
              ],
              ['Testigos', report.testigos],
              ['Efectos personales', report.efectosPersonales],
            ]),
          ),
          _buildDrivers(report.conductores),
          _buildVehicles(report.vehiculos),
          _buildPeople(report.personas),
          _section(
            'Ubicacion',
            _table([
              ['Lugar textual', report.lugar],
              ['Latitud', report.latitud?.toStringAsFixed(6)],
              ['Longitud', report.longitud?.toStringAsFixed(6)],
            ]),
          ),
          _buildSketch(sketch, report.rutaCroquis),
          _buildPhotos(photos),
          _buildPoliceAndQr(owner, qr.payload.toStructuredText()),
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

  pw.Widget _buildHeader(ReportRecord report) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORME DE ACCION DIRECTA',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Caso ${report.numeroCaso}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Pagina ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _buildDrivers(List<DriverRecord> drivers) {
    return _section(
      'Conductores',
      drivers.isEmpty
          ? _emptyText('Sin conductores registrados.')
          : pw.Column(
              children: [
                for (final (index, driver) in drivers.indexed)
                  _recordBlock('Conductor ${index + 1}', [
                    ['Nombre completo', driver.nombreCompleto],
                    ['Edad', driver.edad?.toString()],
                    ['Licencia', driver.licencia],
                    ['Categoria', driver.categoria],
                    ['Domicilio', driver.domicilio],
                    ['Zona', driver.zona],
                    ['Contactos', driver.contactos],
                    ['Condicion de entrega', driver.condicionEntrega],
                  ]),
              ],
            ),
    );
  }

  pw.Widget _buildVehicles(List<VehicleRecord> vehicles) {
    return _section(
      'Vehiculos',
      vehicles.isEmpty
          ? _emptyText('Sin vehiculos registrados.')
          : pw.Column(
              children: [
                for (final (index, vehicle) in vehicles.indexed)
                  _recordBlock('Vehiculo ${index + 1}', [
                    ['Placa', vehicle.placa],
                    ['Marca', vehicle.marca],
                    ['Color', vehicle.color],
                    ['Tipo', vehicle.tipo],
                    ['Servicio', vehicle.servicio],
                    [
                      'Id conductor relacionado',
                      vehicle.idConductor?.toString(),
                    ],
                  ]),
              ],
            ),
    );
  }

  pw.Widget _buildPeople(List<PersonRecord> people) {
    return _section(
      'Personas involucradas',
      people.isEmpty
          ? _emptyText('Sin personas involucradas registradas.')
          : pw.Column(
              children: [
                for (final (index, person) in people.indexed)
                  _recordBlock('Persona ${index + 1}', [
                    ['Nombre', person.nombre],
                    ['Tipo', _personType(person.tipo)],
                    ['Edad', person.edad?.toString()],
                    ['Lugar de evacuacion', person.lugarEvacuacion],
                  ]),
              ],
            ),
    );
  }

  pw.Widget _buildSketch(_LoadedImage? sketch, String? path) {
    return _section(
      'Croquis cartografico',
      sketch == null
          ? _emptyText(
              _hasText(path)
                  ? 'Croquis no disponible.'
                  : 'Sin croquis registrado.',
            )
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  constraints: const pw.BoxConstraints(maxHeight: 260),
                  child: pw.Image(sketch.image, fit: pw.BoxFit.contain),
                ),
                if (_hasText(path)) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Archivo registrado: ${_fileName(path!)}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  pw.Widget _buildPhotos(List<_LoadedPhoto> photos) {
    return _section(
      'Fotografias',
      photos.isEmpty
          ? _emptyText('Sin fotografias disponibles.')
          : pw.Column(
              children: [
                for (var index = 0; index < photos.length; index += 2)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(child: _photoTile(photos[index])),
                        pw.SizedBox(width: 12),
                        if (index + 1 < photos.length)
                          pw.Expanded(child: _photoTile(photos[index + 1]))
                        else
                          pw.Expanded(child: pw.SizedBox()),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  pw.Widget _buildPoliceAndQr(
    InstitutionalQrPolice owner,
    String payload,
  ) {
    return _section(
      'Funcionario responsable y QR institucional',
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _table([
              ['Nombre', owner.nombreCompleto],
              ['Grado', owner.grado],
              ['Placa', owner.numeroPlaca],
              ['Unidad', owner.unidad],
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            width: 126,
            height: 126,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey700),
            ),
            child: pw.BarcodeWidget(
              data: payload,
              barcode: pw.Barcode.qrCode(),
              drawText: false,
            ),
          ),
        ],
      ),
    );
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
            height: 150,
            width: double.infinity,
            child: pw.Image(photo.image.image, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            photo.label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          if (_hasText(photo.description)) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              photo.description!,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _section(String title, pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  pw.Widget _recordBlock(String title, List<List<String?>> rows) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          _table(rows),
        ],
      ),
    );
  }

  pw.Widget _table(List<List<String?>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(2),
      },
      children: rows
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      color: isHeader ? PdfColors.grey200 : null,
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
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
      ),
      child: pw.Text(
        _value(text),
        style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
      ),
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
    for (final (index, photo) in photos.indexed) {
      final image = await _loadImage(photo.ruta);
      if (image == null) {
        continue;
      }
      loaded.add(
        _LoadedPhoto(
          image: image,
          label: 'Fotografia ${index + 1}: ${photo.tipo.label}',
          description: photo.descripcion,
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

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'No especificado';
    }
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  static String _boolText(bool? value) {
    if (value == null) {
      return 'No especificado';
    }
    return value ? 'Si' : 'No';
  }

  static String _personType(String value) {
    return switch (value) {
      'HERIDO' => 'Herido',
      'FALLECIDO' => 'Fallecido',
      _ => value,
    };
  }

  static String _value(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static String _fileName(String path) {
    return path.split(RegExp(r'[\\/]')).last;
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
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
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

  final _LoadedImage image;
  final String label;
  final String? description;
}
