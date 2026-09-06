import 'package:flutter/material.dart';
import '../../data/repositories/report_repository.dart';
import '../../services/external_apps/external_maps_service.dart';
import '../../services/qr/institutional_qr_service.dart';
import '../../shared/scaffold_shell.dart';
import '../../shared/ui/app_state_view.dart';
import '../../shared/user_message.dart';
import '../auth/domain/authenticated_user.dart';
import 'application/report_controller.dart';
import 'report_detail_content.dart';
import 'report_pdf_preview_page.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.controller,
    required this.actor,
    required this.idInforme,
    required this.externalMapsService,
  });

  final ReportController controller;
  final AuthenticatedUser actor;
  final int idInforme;
  final ExternalMapsService externalMapsService;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late final Future<ReportRecord> _detail;
  late final Future<InstitutionalQrPolice> _owner;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.controller
        .findReadableOwner(actor: widget.actor, idInforme: widget.idInforme);
    // El error se presenta en la sección del funcionario cuando se monta.
    _owner.ignore();
    _detail = widget.controller.findReadableDetail(
      actor: widget.actor,
      idInforme: widget.idInforme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Detalle de informe',
      body: FutureBuilder<ReportRecord>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: AppLoadingState(message: 'Cargando detalle'),
            );
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'No se pudo abrir',
              message: userMessage(snapshot.error!,
                  fallback:
                      'El informe no está disponible o no tiene permiso para consultarlo.'),
            );
          }
          final report = snapshot.data!;
          return ReportDetailContent(
            report: report,
            owner: _owner,
            isGeneratingPdf: _isGeneratingPdf,
            onPdf: _openPdfPreview,
            onMaps: () => _openCoordinatesExternally(report),
          );
        },
      ),
    );
  }

  Future<void> _openCoordinatesExternally(ReportRecord report) async {
    try {
      final opened = await widget.externalMapsService.openCoordinates(
        latitude: report.latitud!,
        longitude: report.longitud!,
      );
      if (!mounted || opened) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró una aplicación compatible de mapas.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userMessage(error,
              fallback: 'No se pudieron abrir las coordenadas.'))));
    }
  }

  Future<void> _openPdfPreview() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = await widget.controller.buildReadablePdf(
        actor: widget.actor,
        idInforme: widget.idInforme,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportPdfPreviewPage(
            controller: widget.controller,
            actor: widget.actor,
            idInforme: widget.idInforme,
            pdf: pdf,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                userMessage(error, fallback: 'No se pudo generar el PDF.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }
}
