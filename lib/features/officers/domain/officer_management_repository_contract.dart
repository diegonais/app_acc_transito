import 'officer_record.dart';

/// Operaciones actuales de gestión de policías, independientes del motor de datos.
abstract interface class OfficerManagementRepositoryContract {
  Future<List<OfficerRecord>> listOfficers();

  Future<int> createOfficerAccount(OfficerAccountInput input, {DateTime? now});

  Future<void> updateOfficerAdministrativeData(
    OfficerUpdateInput input, {
    DateTime? now,
  });

  Future<void> setOfficerActive({
    required int idPolicia,
    required int idUsuario,
    required bool isActive,
    DateTime? now,
  });

  Future<void> resetPassword({
    required int idUsuario,
    required String passwordHash,
    DateTime? now,
  });
}
