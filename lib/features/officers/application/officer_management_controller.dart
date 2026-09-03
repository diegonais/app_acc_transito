import 'package:flutter/foundation.dart';

import '../../auth/data/password_hasher.dart';
import '../../auth/domain/app_role.dart';
import '../../auth/domain/authenticated_user.dart';
import '../data/officer_management_repository.dart';
import '../domain/officer_record.dart';

class OfficerManagementController extends ChangeNotifier {
  OfficerManagementController({
    required OfficerManagementRepository repository,
    required PasswordHasher passwordHasher,
  })  : _repository = repository,
        _passwordHasher = passwordHasher;

  final OfficerManagementRepository _repository;
  final PasswordHasher _passwordHasher;

  bool _isLoading = false;
  String? _errorMessage;
  List<OfficerRecord> _officers = const [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<OfficerRecord> get officers => _officers;

  Future<void> load(AuthenticatedUser actor) async {
    _requireAdmin(actor);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _officers = await _repository.listOfficers();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createOfficer({
    required AuthenticatedUser actor,
    required String numeroPlaca,
    required String grado,
    required String nombres,
    required String apellidos,
    required String unidad,
    required String sigla,
    required String ci,
    required String username,
    required String initialPassword,
    required bool isActive,
  }) async {
    _requireAdmin(actor);
    _validateRequired({
      'numero de placa': numeroPlaca,
      'grado': grado,
      'nombres': nombres,
      'apellidos': apellidos,
      'unidad': unidad,
      'C.I.': ci,
      'usuario': username,
    });
    _validatePassword(initialPassword);

    await _repository.createOfficerAccount(
      OfficerAccountInput(
        numeroPlaca: numeroPlaca,
        grado: grado,
        nombres: nombres,
        apellidos: apellidos,
        unidad: unidad,
        sigla: sigla,
        ci: ci,
        username: username,
        passwordHash: await _passwordHasher.hash(initialPassword),
        isActive: isActive,
      ),
    );
    await load(actor);
  }

  Future<void> updateOfficer({
    required AuthenticatedUser actor,
    required int idPolicia,
    required int idUsuario,
    required String numeroPlaca,
    required String grado,
    required String nombres,
    required String apellidos,
    required String unidad,
    required String sigla,
    required String ci,
    required String username,
  }) async {
    _requireAdmin(actor);
    _validateRequired({
      'numero de placa': numeroPlaca,
      'grado': grado,
      'nombres': nombres,
      'apellidos': apellidos,
      'unidad': unidad,
      'C.I.': ci,
      'usuario': username,
    });

    await _repository.updateOfficerAdministrativeData(
      OfficerUpdateInput(
        idPolicia: idPolicia,
        idUsuario: idUsuario,
        numeroPlaca: numeroPlaca,
        grado: grado,
        nombres: nombres,
        apellidos: apellidos,
        unidad: unidad,
        sigla: sigla,
        ci: ci,
        username: username,
      ),
    );
    await load(actor);
  }

  Future<void> setOfficerActive({
    required AuthenticatedUser actor,
    required OfficerRecord officer,
    required bool isActive,
  }) async {
    _requireAdmin(actor);
    await _repository.setOfficerActive(
      idPolicia: officer.idPolicia,
      idUsuario: officer.idUsuario,
      isActive: isActive,
    );
    await load(actor);
  }

  Future<void> resetPassword({
    required AuthenticatedUser actor,
    required OfficerRecord officer,
    required String newPassword,
  }) async {
    _requireAdmin(actor);
    _validatePassword(newPassword);
    await _repository.resetPassword(
      idUsuario: officer.idUsuario,
      passwordHash: await _passwordHasher.hash(newPassword),
    );
  }

  void _requireAdmin(AuthenticatedUser actor) {
    if (actor.role != AppRole.admin) {
      throw StateError('Operacion permitida solo para ADMIN.');
    }
  }

  void _validateRequired(Map<String, String> fields) {
    for (final entry in fields.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError('Debe ingresar ${entry.key}.');
      }
    }
    if (fields['usuario']!.trim().length < 3) {
      throw ArgumentError('El usuario debe tener al menos 3 caracteres.');
    }
  }

  void _validatePassword(String password) {
    if (password.length < 8) {
      throw ArgumentError('La contrasena debe tener al menos 8 caracteres.');
    }
  }
}
