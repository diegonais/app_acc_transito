import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/online_session_contract.dart';

import '../domain/auth_repository_contract.dart';
import '../domain/app_role.dart';
import '../domain/authenticated_user.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authRepository) {
    final repository = _authRepository;
    if (repository is OnlineSessionContract) {
      _sessionSubscription =
          (repository as OnlineSessionContract).sessionChanges.listen((active) {
        if (!active) _clearSession();
      }, onError: (Object _) {
        _connectionMessage =
            'No se pudo renovar la sesión. Compruebe Internet y vuelva a ingresar si es necesario.';
        notifyListeners();
      });
    }
  }

  StreamSubscription<bool>? _sessionSubscription;
  String? _connectionMessage;
  String? get connectionMessage => _connectionMessage;
  bool get isOnline => _authRepository is OnlineSessionContract;

  Future<void> restoreSession() async {
    final repository = _authRepository;
    if (repository is! OnlineSessionContract) return;
    final generation = ++_loginGeneration;
    final user = await (repository as OnlineSessionContract).restoreSession();
    if (generation != _loginGeneration) return;
    _currentUser = user;
    notifyListeners();
  }

  final AuthRepositoryContract _authRepository;
  AuthenticatedUser? _currentUser;
  int _loginGeneration = 0;

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _loginGeneration++;
    super.dispose();
  }

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
    if (isOnline) _clearSession();
    final generation = ++_loginGeneration;
    final user = await _authRepository.login(
      username: username,
      password: password,
    );
    if (generation != _loginGeneration) return;
    _currentUser = user;
    _connectionMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _clearSession();
    final repository = _authRepository;
    if (repository is OnlineSessionContract) {
      await (repository as OnlineSessionContract).signOut();
    }
  }

  void _clearSession() {
    _loginGeneration++;
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
      throw StateError('No existe una sesión activa.');
    }
    if (policeUsername.trim().isEmpty) {
      throw ArgumentError('Debe ingresar el usuario del policía.');
    }
    if (newPassword.length < 8) {
      throw ArgumentError(
          'La nueva contraseña debe tener al menos 8 caracteres.');
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
      throw StateError('No existe una sesión activa.');
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
      throw ArgumentError('La contraseña debe tener al menos 8 caracteres.');
    }
  }
}
