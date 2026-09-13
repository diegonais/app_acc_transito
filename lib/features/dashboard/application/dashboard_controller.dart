import 'package:flutter/foundation.dart';
import '../../../data/models/report_date_bounds.dart';
import '../../../shared/user_message.dart';

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
  int _loadGeneration = 0;

  void reset() {
    _loadGeneration++;
    _stats = null;
    _selectedDate = DateTime.now();
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
  DashboardStats? get stats => _stats;
  DateTime get selectedDate => _selectedDate;

  Future<ReportDateBounds> loadDateBounds(AuthenticatedUser actor) {
    return _repository.loadDateBounds(
      idPolicia: actor.isAdmin ? null : actor.requiredPoliceId,
    );
  }

  Future<void> load(
    AuthenticatedUser actor, {
    DateTime? referenceDate,
    DateTime? selectedDate,
  }) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bounds = await loadDateBounds(actor);
      if (generation != _loadGeneration) return;
      final queryDate = selectedDate ?? bounds.clamp(_selectedDate);
      final reference = referenceDate ?? _repository.clock();
      final stats = actor.role == AppRole.admin
          ? await _repository.loadAdminDashboard(
              referenceDate: reference,
              selectedDate: queryDate,
            )
          : await _repository.loadPoliceDashboard(
              idPolicia: actor.requiredPoliceId,
              referenceDate: reference,
              selectedDate: queryDate,
            );
      if (generation != _loadGeneration) return;
      _selectedDate = queryDate;
      _stats = stats;
    } catch (error) {
      if (generation != _loadGeneration) return;
      _stats = null;
      _errorMessage =
          userMessage(error, fallback: 'No se pudo cargar el resumen.');
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
