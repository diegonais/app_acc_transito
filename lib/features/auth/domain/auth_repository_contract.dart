import 'app_role.dart';
import 'authenticated_user.dart';

/// Acceso a las operaciones de autenticación que utiliza el controlador.
abstract interface class AuthRepositoryContract {
  Future<bool> hasAdmin();

  Future<int> createFirstAdmin({
    required String username,
    required String password,
    DateTime? now,
  });

  Future<AuthenticatedUser> login({
    required String username,
    required String password,
  });

  Future<void> resetPolicePassword({
    required AuthenticatedUser actor,
    required String policeUsername,
    required String newPassword,
    DateTime? now,
  });

  void requireRole(AuthenticatedUser user, AppRole role);
}
