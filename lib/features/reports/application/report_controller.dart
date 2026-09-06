import 'package:flutter/foundation.dart';
import '../../../shared/user_message.dart';

import '../../../data/repositories/report_repository.dart';
import '../../../services/files/report_pdf_file_service.dart';
import '../../../services/pdf/direct_action_report_pdf_service.dart';
import '../../../services/qr/institutional_qr_service.dart';
import '../../auth/domain/app_role.dart';
import '../../auth/domain/authenticated_user.dart';

class DirectActionReportDraft {
  const DirectActionReportDraft({
    required this.epi,
    required this.fechaHoraLlegada,
    required this.fechaHoraHecho,
    required this.naturaleza,
    required this.lugar,
    required this.denuncianteNombre,
    required this.denuncianteDocumento,
    required this.denuncianteContacto,
    required this.descripcion,
    required this.condicionesClimaticas,
    required this.vehiculosMovidos,
    required this.protagonistasPresentes,
    required this.testigos,
    required this.efectosPersonales,
    this.latitud,
    this.longitud,
    this.rutaCroquis,
    this.conductores = const [],
    this.vehiculos = const [],
    this.personas = const [],
    this.fotografias = const [],
  });

  final String epi;
  final DateTime? fechaHoraLlegada;
  final DateTime? fechaHoraHecho;
  final String naturaleza;
  final String lugar;
  final String denuncianteNombre;
  final String denuncianteDocumento;
  final String denuncianteContacto;
  final String descripcion;
  final String condicionesClimaticas;
  final bool? vehiculosMovidos;
  final bool? protagonistasPresentes;
  final String testigos;
  final String efectosPersonales;
  final double? latitud;
  final double? longitud;
  final String? rutaCroquis;
  final List<DriverInput> conductores;
  final List<VehicleInput> vehiculos;
  final List<PersonInput> personas;
  final List<PhotoInput> fotografias;

  bool get hasData {
    return [
          epi,
          naturaleza,
          lugar,
          denuncianteNombre,
          denuncianteDocumento,
          denuncianteContacto,
          descripcion,
          condicionesClimaticas,
          testigos,
          efectosPersonales,
          rutaCroquis ?? '',
        ].any((value) => value.trim().isNotEmpty) ||
        fechaHoraLlegada != null ||
        fechaHoraHecho != null ||
        vehiculosMovidos != null ||
        protagonistasPresentes != null ||
        latitud != null ||
        longitud != null ||
        conductores.isNotEmpty ||
        vehiculos.isNotEmpty ||
        personas.isNotEmpty ||
        fotografias.isNotEmpty;
  }
}

class ReportController extends ChangeNotifier {
  ReportController({required ReportRepository repository})
      : _repository = repository;

  final ReportRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  List<ReportRecord> _reports = const [];
  List<PoliceReportCount> _policeOptions = const [];
  ReportQueryFilter _filter = const ReportQueryFilter();
  int _loadGeneration = 0;

  void reset() {
    _loadGeneration++;
    _reports = const [];
    _policeOptions = const [];
    _filter = const ReportQueryFilter();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ReportRecord> get reports => _reports;
  List<PoliceReportCount> get policeOptions => _policeOptions;
  ReportQueryFilter get filter => _filter;

  Future<void> load(
    AuthenticatedUser actor, {
    ReportQueryFilter? filter,
  }) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    if (filter != null) {
      _filter = filter;
    }
    notifyListeners();

    try {
      if (actor.role == AppRole.admin) {
        final options = await _repository.listPoliceReportCounts();
        final reports = await _repository.queryActiveReportsForAdmin(
          filter: _filter,
        );
        if (generation != _loadGeneration) return;
        _policeOptions = options;
        _reports = reports;
      } else {
        _policeOptions = const [];
        final reports = await _repository.queryActiveReportsForPolice(
          idPolicia: actor.requiredPoliceId,
          filter: _filter,
        );
        if (generation != _loadGeneration) return;
        _reports = reports;
      }
    } catch (error) {
      if (generation != _loadGeneration) return;
      _reports = const [];
      _errorMessage =
          userMessage(error, fallback: 'No se pudieron cargar los informes.');
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<FinalizedReport> finalize({
    required AuthenticatedUser actor,
    required DirectActionReportDraft draft,
    DateTime? now,
    PersistPhotosForCase? persistPhotosForCase,
    CleanupPhotos? cleanupPersistedPhotos,
  }) async {
    if (actor.role != AppRole.police) {
      throw StateError('Solo un usuario POLICE puede crear informes.');
    }
    final reference = now ?? DateTime.now();
    final finalized = await _repository.finalizeReport(
      FinalizeReportInput(
        idPolicia: actor.requiredPoliceId,
        gestion: draft.fechaHoraHecho?.year ?? reference.year,
        epi: draft.epi.trim(),
        fechaHoraLlegada: draft.fechaHoraLlegada,
        fechaHoraHecho: draft.fechaHoraHecho,
        naturaleza: draft.naturaleza.trim(),
        lugar: draft.lugar.trim(),
        latitud: draft.latitud,
        longitud: draft.longitud,
        denuncianteNombre: draft.denuncianteNombre.trim(),
        denuncianteDocumento: _optionalText(draft.denuncianteDocumento),
        denuncianteContacto: draft.denuncianteContacto.trim(),
        descripcion: draft.descripcion.trim(),
        condicionesClimaticas: draft.condicionesClimaticas.trim(),
        vehiculosMovidos: draft.vehiculosMovidos,
        protagonistasPresentes: draft.protagonistasPresentes,
        testigos: draft.testigos.trim(),
        efectosPersonales: draft.efectosPersonales.trim(),
        rutaCroquis: _optionalText(draft.rutaCroquis),
        conductores: draft.conductores,
        vehiculos: draft.vehiculos,
        personas: draft.personas,
        fotografias: draft.fotografias,
      ),
      now: reference,
      persistPhotosForCase: persistPhotosForCase,
      cleanupPersistedPhotos: cleanupPersistedPhotos,
    );
    await load(actor);
    return finalized;
  }

  Future<ReportRecord> findReadableDetail({
    required AuthenticatedUser actor,
    required int idInforme,
  }) async {
    final report = actor.role == AppRole.admin
        ? await _repository.findActiveReportDetail(idInforme)
        : await _repository.findActiveReportDetailForPolice(
            idInforme: idInforme,
            idPolicia: actor.requiredPoliceId,
          );
    if (report == null) {
      throw StateError('El informe no existe o está inactivo.');
    }
    return report;
  }

  Future<InstitutionalQrPolice> findReadableOwner({
    required AuthenticatedUser actor,
    required int idInforme,
  }) async {
    final report = await findReadableDetail(actor: actor, idInforme: idInforme);
    return _repository.findReportOwnerQrIdentity(report.idPolicia);
  }

  Future<DirectActionReportPdf> buildReadablePdf({
    required AuthenticatedUser actor,
    required int idInforme,
    DirectActionReportPdfService? pdfService,
  }) async {
    final report = await findReadableDetail(
      actor: actor,
      idInforme: idInforme,
    );
    final owner = await _repository.findReportOwnerQrIdentity(report.idPolicia);
    return (pdfService ?? DirectActionReportPdfService()).build(
      report: report,
      owner: owner,
    );
  }

  Future<String> saveReadablePdf({
    required AuthenticatedUser actor,
    required int idInforme,
    required DirectActionReportPdf pdf,
    ReportPdfFileService fileService = const ReportPdfFileService(),
  }) async {
    await findReadableDetail(actor: actor, idInforme: idInforme);
    final path = await fileService.save(
      bytes: pdf.bytes,
      fileName: pdf.fileName,
    );
    await _repository.updatePdfPath(idInforme: idInforme, rutaPdf: path);
    return path;
  }

  Future<void> inactivate({
    required AuthenticatedUser actor,
    required int idInforme,
  }) async {
    if (actor.role != AppRole.admin) {
      throw StateError('Solo ADMIN puede inactivar informes.');
    }
    await _repository.inactivateReport(idInforme: idInforme);
    await load(actor);
  }

  static String? _optionalText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
