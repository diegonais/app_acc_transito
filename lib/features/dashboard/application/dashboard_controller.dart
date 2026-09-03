import 'package:flutter/foundation.dart';

import '../../../data/repositories/report_repository.dart';
import '../../auth/domain/app_role.dart';
import '../../auth/domain/authenticated_user.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({required ReportRepository repository})
      : _repository = repository;

  final ReportRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  DashboardStats? _stats;
  DateTime _selectedDate = DateTime.now();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardStats? get stats => _stats;
  DateTime get selectedDate => _selectedDate;

  Future<void> load(
    AuthenticatedUser actor, {
    DateTime? referenceDate,
    DateTime? selectedDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    if (selectedDate != null) {
      _selectedDate = selectedDate;
    }
    notifyListeners();

    try {
      final reference = referenceDate ?? DateTime.now();
      _stats = actor.role == AppRole.admin
          ? await _repository.loadAdminDashboard(
              referenceDate: reference,
              selectedDate: _selectedDate,
            )
          : await _repository.loadPoliceDashboard(
              idPolicia: actor.requiredPoliceId,
              referenceDate: reference,
              selectedDate: _selectedDate,
            );
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
