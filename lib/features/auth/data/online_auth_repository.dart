import '../../../data/remote/remote_gateway.dart';
import '../domain/auth_repository_contract.dart';
import '../domain/online_session_contract.dart';
import '../domain/app_role.dart';
import '../domain/authenticated_user.dart';
import '../domain/auth_exceptions.dart';

class OnlineAuthRepository
    implements AuthRepositoryContract, OnlineSessionContract {
  OnlineAuthRepository(this.gateway);
  final RemoteGateway gateway;
  @override
  Stream<bool> get sessionChanges => gateway.sessionChanges;
  @override
  Future<bool> hasAdmin() async =>
      true; // Nunca configurar cuentas desde ONLINE.
  @override
  Future<AuthenticatedUser?> restoreSession() async =>
      gateway.userId == null ? null : _identity();
  @override
  Future<AuthenticatedUser> login(
      {required String username, required String password}) async {
    try {
      await gateway.signIn(username.trim(), password);
      return await _identity();
    } catch (_) {
      // No mostrar cuerpos de Auth ni credenciales; tampoco conservar una
      // identidad anterior si falla el perfil de la nueva sesión.
      throw const AuthException(
          'No se pudo ingresar en línea. Revise correo, contraseña, conexión y cuenta activa.');
    }
  }

  Future<AuthenticatedUser> _identity() async {
    final uid = gateway.userId;
    if (uid == null)
      throw const AuthException('La sesión en línea ha terminado.');
    final users = await gateway
        .select('usuarios', equals: {'auth_uid': uid, 'estado': 1});
    if (users.length != 1) throw const InactiveUserException();
    final u = users.single;
    final role = switch (u['rol']) {
      'ADMIN' => AppRole.admin,
      'POLICE' => AppRole.police,
      _ => throw const AuthorizationException('Rol no autorizado.'),
    };
    PoliceProfile? profile;
    if (role == AppRole.police) {
      final rows = await gateway.select('policias',
          equals: {'id_usuario': u['id_usuario'] as int, 'estado': 1});
      if (rows.length != 1) throw const MissingPoliceProfileException();
      final p = rows.single;
      profile = PoliceProfile(
          idPolicia: p['id_policia'],
          numeroPlaca: p['numero_placa'],
          grado: p['grado'],
          nombres: p['nombres'],
          apellidos: p['apellidos'],
          unidad: p['unidad'],
          sigla: p['sigla'],
          ci: p['ci']);
    }
    // Tablas sujetas a RLS; jamás user_metadata ni selección de rol en UI.
    return AuthenticatedUser(
        idUsuario: u['id_usuario'],
        username: u['nombre_usuario'],
        role: role,
        policeProfile: profile);
  }

  @override
  Future<void> signOut() => gateway.signOut();
  @override
  void requireRole(AuthenticatedUser user, AppRole role) {
    if (user.role != role)
      throw const AuthorizationException('Operación no autorizada.');
  }

  @override
  Future<int> createFirstAdmin(
          {required String username,
          required String password,
          DateTime? now}) async =>
      throw const AuthorizationException(
          'El alta de cuentas en línea no está disponible.');
  @override
  Future<void> resetPolicePassword(
          {required AuthenticatedUser actor,
          required String policeUsername,
          required String newPassword,
          DateTime? now}) async =>
      throw const AuthorizationException(
          'El restablecimiento en línea no está disponible.');
}
