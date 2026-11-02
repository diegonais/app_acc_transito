import '../../../data/remote/remote_gateway.dart';
import '../domain/officer_management_repository_contract.dart';
import '../domain/officer_record.dart';

/// No existe un contrato servidor de administración de cuentas en este alcance.
class OnlineOfficerManagementRepository
    implements OfficerManagementRepositoryContract {
  Never _unavailable() => throw const OnlineException(
      'La administración de cuentas en línea no está disponible.');
  @override
  Future<List<OfficerRecord>> listOfficers() async => _unavailable();
  @override
  Future<int> createOfficerAccount(OfficerAccountInput input,
          {DateTime? now}) async =>
      _unavailable();
  @override
  Future<void> updateOfficerAdministrativeData(OfficerUpdateInput input,
          {DateTime? now}) async =>
      _unavailable();
  @override
  Future<void> setOfficerActive(
          {required int idPolicia,
          required int idUsuario,
          required bool isActive,
          DateTime? now}) async =>
      _unavailable();
  @override
  Future<void> resetPassword(
          {required int idUsuario,
          required String passwordHash,
          DateTime? now}) async =>
      _unavailable();
}
