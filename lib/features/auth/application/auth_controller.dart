import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../domain/app_role.dart';
import '../domain/authenticated_user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authRepository);

  final AuthRepository _authRepository;
  AuthenticatedUser? _currentUser;

  AuthenticatedUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> hasAdmin() {
    return _authRepository.hasAdmin();
  }

  Future<void> createFirstAdmin({
    required String username,
    required String password,
  }) async {
    _validateCredentials(username: username, password: password);
    await _authRepository.createFirstAdmin(
      username: username,
      password: password,
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _validateCredentials(username: username, password: password);
    _currentUser = await _authRepository.login(
      username: username,
      password: password,
    );
    notifyListeners();
  }

  void logout() {
    if (_currentUser == null) {
      return;
    }
    _currentUser = null;
    notifyListeners();
  }

  Future<void> resetPolicePassword({
    required String policeUsername,
    required String newPassword,
  }) async {
    final actor = _currentUser;
    if (actor == null) {
      throw StateError('No existe una sesion activa.');
    }
    if (policeUsername.trim().isEmpty) {
      throw ArgumentError('Debe ingresar el usuario del policia.');
    }
    if (newPassword.length < 8) {
      throw ArgumentError(
          'La nueva contrasena debe tener al menos 8 caracteres.');
    }

    await _authRepository.resetPolicePassword(
      actor: actor,
      policeUsername: policeUsername,
      newPassword: newPassword,
    );
  }

  void requireRole(AppRole role) {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No existe una sesion activa.');
    }
    _authRepository.requireRole(user, role);
  }

  void _validateCredentials({
    required String username,
    required String password,
  }) {
    if (username.trim().length < 3) {
      throw ArgumentError('El usuario debe tener al menos 3 caracteres.');
    }
    if (password.length < 8) {
      throw ArgumentError('La contrasena debe tener al menos 8 caracteres.');
    }
  }
}
