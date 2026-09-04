import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/services/pdf/direct_action_report_pdf_service.dart';
import 'package:app_acc_transito/services/qr/institutional_qr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('integra el QR institucional en el PDF generado', () async {
    final report = ReportRecord(
      idInforme: 1,
      idPolicia: 10,
      gestion: 2026,
      correlativo: 1,
      numeroCaso: '2026-000001',
      epi: 'EPI Norte',
      estado: 1,
      fechaCreacion: DateTime.utc(2026),
      fechaModificacion: DateTime.utc(2026),
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
    final report = ReportRecord(
      idInforme: 1,
      idPolicia: 10,
      gestion: 2026,
      correlativo: 12,
      numeroCaso: '2026-000012',
      epi: 'EPI Norte',
      estado: 1,
      fechaCreacion: DateTime.utc(2026),
      fechaModificacion: DateTime.utc(2026),
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
}
