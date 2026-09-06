import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/pdf/direct_action_report_pdf_service.dart';
import '../../services/share/report_pdf_share_service.dart';
import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_button.dart';
import '../auth/domain/authenticated_user.dart';
import 'application/report_controller.dart';

class ReportPdfPreviewPage extends StatefulWidget {
  const ReportPdfPreviewPage({
    super.key,
    required this.controller,
    required this.actor,
    required this.idInforme,
    required this.pdf,
    this.shareService = const ReportPdfShareService(),
  });

  final ReportController controller;
  final AuthenticatedUser actor;
  final int idInforme;
  final DirectActionReportPdf pdf;
  final ReportPdfShareService shareService;

  @override
  State<ReportPdfPreviewPage> createState() => _ReportPdfPreviewPageState();
}

class _ReportPdfPreviewPageState extends State<ReportPdfPreviewPage> {
  bool _isSaving = false;
  bool _isSharing = false;
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Vista previa PDF',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: _isSaving ? 'Guardando' : 'Guardar PDF',
                  icon: Icons.save_alt_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _isBusy ? null : _savePdf,
                ),
                AppButton(
                  label: _isSharing ? 'Compartiendo' : 'Compartir',
                  icon: Icons.ios_share_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _isBusy ? null : _sharePdf,
                ),
                AppButton(
                  label: _isPrinting ? 'Imprimiendo' : 'Imprimir',
                  icon: Icons.print_outlined,
                  onPressed: _isBusy ? null : _printPdf,
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) async => widget.pdf.bytes,
              initialPageFormat: PdfPageFormat.a4,
              pdfFileName: widget.pdf.fileName,
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              loadingWidget: const Center(
                child: CircularProgressIndicator(),
              ),
              onError: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No se pudo previsualizar el PDF: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isBusy => _isSaving || _isSharing || _isPrinting;

  Future<void> _savePdf() async {
    setState(() => _isSaving = true);
    try {
      await widget.controller.saveReadablePdf(
        actor: widget.actor,
        idInforme: widget.idInforme,
        pdf: widget.pdf,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF guardado correctamente.')),
      );
    } catch (error) {
      _showError('No se pudo guardar el PDF: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isSharing = true);
    try {
      final result = await widget.shareService.sharePdf(
        bytes: widget.pdf.bytes,
        fileName: widget.pdf.fileName,
        subject: 'Informe ${widget.pdf.fileName}',
        text: 'Informe de Accion Directa.',
      );
      if (!mounted) {
        return;
      }
      if (result.status == ShareResultStatus.dismissed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compartir cancelado.')),
        );
      }
    } catch (error) {
      _showError('No se pudo compartir el PDF: $error');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _printPdf() async {
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        name: widget.pdf.fileName,
        format: PdfPageFormat.a4,
        onLayout: (_) async => widget.pdf.bytes,
      );
    } catch (error) {
      _showError('No se pudo imprimir el PDF: $error');
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
