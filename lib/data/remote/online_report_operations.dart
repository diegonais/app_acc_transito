import '../models/report_models.dart';

/// Capacidades propias de ONLINE sin ampliar las obligaciones de SQLite.
abstract interface class OnlineReportOperations {
  bool get hasPendingFinalization;
  Future<FinalizedReport> resumeFinalization();
  Future<void> beginReport();
  Future<void> uploadPdf(int reportId, String path);
}
