import 'package:flutter/foundation.dart';

import '../../../data/repositories/report_repository.dart';
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

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ReportRecord> get reports => _reports;

  Future<void> load(AuthenticatedUser actor) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reports = actor.role == AppRole.admin
          ? await _repository.listActiveReportsForAdmin()
          : await _repository
              .listActiveReportsForPolice(actor.requiredPoliceId);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
    final report = await _repository.findActiveReportDetail(idInforme);
    if (report == null) {
      throw StateError('El informe no existe o esta inactivo.');
    }
    if (actor.role == AppRole.police &&
        report.idPolicia != actor.requiredPoliceId) {
      throw StateError('El informe no pertenece al policia autenticado.');
    }
    return report;
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
