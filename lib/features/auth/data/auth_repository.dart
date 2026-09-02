import '../../../data/repositories/police_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../domain/app_role.dart';
import '../domain/auth_exceptions.dart';
import '../domain/authenticated_user.dart';
import 'password_hasher.dart';

class AuthRepository {
  const AuthRepository({
    required UserRepository userRepository,
    required PoliceRepository policeRepository,
    required PasswordHasher passwordHasher,
  })  : _userRepository = userRepository,
        _policeRepository = policeRepository,
        _passwordHasher = passwordHasher;

  final UserRepository _userRepository;
  final PoliceRepository _policeRepository;
  final PasswordHasher _passwordHasher;

  Future<bool> hasAdmin() async {
    return (await _userRepository.countAdmins()) > 0;
  }

  Future<int> createFirstAdmin({
    required String username,
    required String password,
    DateTime? now,
  }) async {
    if (await hasAdmin()) {
      throw const AuthorizationException('Ya existe una cuenta ADMIN.');
    }

    return _userRepository.createUser(
      username: username.trim(),
      passwordHash: await _passwordHasher.hash(password),
      role: AppRole.admin.databaseValue,
      now: now,
    );
  }

  Future<AuthenticatedUser> login({
    required String username,
    required String password,
  }) async {
    final user = await _userRepository.findByUsername(username.trim());
    if (user == null) {
      throw const InvalidCredentialsException();
    }

    if (user['estado'] != 1) {
      throw const InactiveUserException();
    }

    final passwordHash = user['contrasena_hash'] as String;
    final isValid = await _passwordHasher.verify(
      password: password,
      encodedHash: passwordHash,
    );
    if (!isValid) {
      throw const InvalidCredentialsException();
    }

    final role = AppRole.fromDatabase(user['rol'] as String);
    final idUsuario = user['id_usuario'] as int;
    PoliceProfile? policeProfile;

    if (role == AppRole.police) {
      final police = await _policeRepository.findActiveByUserId(idUsuario);
      if (police == null) {
        throw const MissingPoliceProfileException();
      }
      policeProfile = _mapPolice(police);
    }

    return AuthenticatedUser(
      idUsuario: idUsuario,
      username: user['nombre_usuario'] as String,
      role: role,
      policeProfile: policeProfile,
    );
  }

  Future<void> resetPolicePassword({
    required AuthenticatedUser actor,
    required String policeUsername,
    required String newPassword,
    DateTime? now,
  }) async {
    requireRole(actor, AppRole.admin);

    final policeUser = await _userRepository.findByUsername(
      policeUsername.trim(),
    );
    if (policeUser == null ||
        AppRole.fromDatabase(policeUser['rol'] as String) != AppRole.police) {
      throw const AuthException('No existe un usuario policia con ese nombre.');
    }

    await _userRepository.updatePasswordHash(
      idUsuario: policeUser['id_usuario'] as int,
      passwordHash: await _passwordHasher.hash(newPassword),
      now: now,
    );
  }

  void requireRole(AuthenticatedUser user, AppRole role) {
    if (user.role != role) {
      throw AuthorizationException(
        'Operacion permitida solo para ${role.databaseValue}.',
      );
    }
  }

  PoliceProfile _mapPolice(Map<String, Object?> police) {
    return PoliceProfile(
      idPolicia: police['id_policia'] as int,
      numeroPlaca: police['numero_placa'] as String,
      grado: police['grado'] as String,
      nombres: police['nombres'] as String,
      apellidos: police['apellidos'] as String,
      unidad: police['unidad'] as String,
      sigla: police['sigla'] as String,
      ci: police['ci'] as String,
    );
  }
}
