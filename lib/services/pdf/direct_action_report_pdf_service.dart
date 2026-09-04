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
    final payload = qr.payload.toStructuredText();
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Informe de Accion Directa',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Numero de caso: ${report.numeroCaso}'),
          pw.Text('EPI: ${report.epi}'),
          pw.Text('Naturaleza: ${_fallback(report.naturaleza)}'),
          pw.Text('Lugar: ${_fallback(report.lugar)}'),
          pw.SizedBox(height: 18),
          pw.Text(
            'QR institucional',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 120,
                height: 120,
                color: PdfColors.white,
                child: pw.BarcodeWidget(
                  data: payload,
                  barcode: pw.Barcode.qrCode(),
                  drawText: false,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Text(payload),
              ),
            ],
          ),
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

  static String _fallback(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? 'No aplica' : trimmed;
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
