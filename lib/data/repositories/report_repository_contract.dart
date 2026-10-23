import '../models/report_date_bounds.dart';
import '../models/report_models.dart';
import '../../services/qr/institutional_qr_service.dart';

export '../models/report_models.dart';

/// Operaciones utilizadas por los controladores de informes y dashboard.
abstract interface class ReportRepositoryContract {
  DateTime Function() get clock;

  Future<ReportDateBounds> loadDateBounds({int? idPolicia});

  Future<FinalizedReport> finalizeReport(
    FinalizeReportInput input, {
    DateTime? now,
    PersistPhotosForCase? persistPhotosForCase,
    CleanupPhotos? cleanupPersistedPhotos,
  });

  Future<List<ReportRecord>> queryActiveReportsForAdmin({
    ReportQueryFilter filter = const ReportQueryFilter(),
  });

  Future<List<ReportRecord>> queryActiveReportsForPolice({
    required int idPolicia,
    ReportQueryFilter filter = const ReportQueryFilter(),
  });

  Future<ReportRecord?> findActiveReportDetail(int idInforme);

  Future<ReportRecord?> findActiveReportDetailForPolice({
    required int idInforme,
    required int idPolicia,
  });

  Future<InstitutionalQrPolice> findReportOwnerQrIdentity(int idPolicia);

  Future<DashboardStats> loadAdminDashboard({
    required DateTime referenceDate,
    DateTime? selectedDate,
  });

  Future<DashboardStats> loadPoliceDashboard({
    required int idPolicia,
    required DateTime referenceDate,
    DateTime? selectedDate,
  });

  Future<List<PoliceReportCount>> listPoliceReportCounts();

  Future<void> inactivateReport({required int idInforme, DateTime? now});

  Future<void> updatePdfPath({
    required int idInforme,
    required String rutaPdf,
    DateTime? now,
  });
}
