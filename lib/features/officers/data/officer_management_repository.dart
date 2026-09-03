import '../../../data/database/app_database.dart';
import '../../../data/database/dao/police_dao.dart';
import '../../../data/database/dao/user_dao.dart';
import '../../auth/domain/app_role.dart';
import '../domain/officer_management_exceptions.dart';
import '../domain/officer_record.dart';

class OfficerManagementRepository {
  const OfficerManagementRepository(this._database);

  final AppDatabase _database;

  Future<List<OfficerRecord>> listOfficers() async {
    final db = await _database.instance;
    final rows = await PoliceDao(db).findAllWithUsers();
    return rows.map(_mapOfficer).toList(growable: false);
  }

  Future<int> createOfficerAccount(
    OfficerAccountInput input, {
    DateTime? now,
  }) async {
    return _database.transaction((transaction) async {
      final users = UserDao(transaction);
      final police = PoliceDao(transaction);
      final username = input.username.trim();
      final plate = input.numeroPlaca.trim();

      if (await users.findByUsername(username) != null) {
        throw const DuplicateUsernameException();
      }
      if (await police.findByPlate(plate) != null) {
        throw const DuplicatePlateException();
      }

      final timestamp = (now ?? DateTime.now()).toIso8601String();
      final estado = input.isActive ? 1 : 0;
      final idUsuario = await users.insert({
        'nombre_usuario': username,
        'contrasena_hash': input.passwordHash,
        'rol': AppRole.police.databaseValue,
        'estado': estado,
        'fecha_creacion': timestamp,
        'fecha_modificacion': timestamp,
      });

      return police.insert({
        'id_usuario': idUsuario,
        'numero_placa': plate,
        'grado': input.grado.trim(),
        'nombres': input.nombres.trim(),
        'apellidos': input.apellidos.trim(),
        'unidad': input.unidad.trim(),
        'sigla': input.sigla.trim(),
        'ci': input.ci.trim(),
        'estado': estado,
        'fecha_creacion': timestamp,
        'fecha_modificacion': timestamp,
      });
    });
  }

  Future<void> updateOfficerAdministrativeData(
    OfficerUpdateInput input, {
    DateTime? now,
  }) async {
    await _database.transaction((transaction) async {
      final users = UserDao(transaction);
      final police = PoliceDao(transaction);
      final username = input.username.trim();
      final plate = input.numeroPlaca.trim();

      if (await users.findByUsernameExceptId(username, input.idUsuario) !=
          null) {
        throw const DuplicateUsernameException();
      }
      if (await police.findByPlateExceptId(plate, input.idPolicia) != null) {
        throw const DuplicatePlateException();
      }

      final timestamp = (now ?? DateTime.now()).toIso8601String();
      final updatedPolice = await police.updateAdministrativeData(
        input.idPolicia,
        {
          'numero_placa': plate,
          'grado': input.grado.trim(),
          'nombres': input.nombres.trim(),
          'apellidos': input.apellidos.trim(),
          'unidad': input.unidad.trim(),
          'sigla': input.sigla.trim(),
          'ci': input.ci.trim(),
          'fecha_modificacion': timestamp,
        },
      );
      final updatedUser = await users.updateUsername(
        input.idUsuario,
        username,
        timestamp,
      );

      if (updatedPolice != 1 || updatedUser != 1) {
        throw StateError('No se pudo actualizar el policia.');
      }
    });
  }

  Future<void> setOfficerActive({
    required int idPolicia,
    required int idUsuario,
    required bool isActive,
    DateTime? now,
  }) async {
    await _database.transaction((transaction) async {
      final timestamp = (now ?? DateTime.now()).toIso8601String();
      final estado = isActive ? 1 : 0;
      final updatedPolice = await PoliceDao(transaction).updateStatus(
        idPolicia,
        estado,
        timestamp,
      );
      final updatedUser = await UserDao(transaction).updateStatus(
        idUsuario,
        estado,
        timestamp,
      );

      if (updatedPolice != 1 || updatedUser != 1) {
        throw StateError('No se pudo actualizar el estado del policia.');
      }
    });
  }

  Future<void> resetPassword({
    required int idUsuario,
    required String passwordHash,
    DateTime? now,
  }) async {
    final db = await _database.instance;
    final updatedRows = await UserDao(db).updatePasswordHash(
      idUsuario,
      passwordHash,
      (now ?? DateTime.now()).toIso8601String(),
    );
    if (updatedRows != 1) {
      throw StateError('No se pudo restablecer la contrasena.');
    }
  }

  OfficerRecord _mapOfficer(Map<String, Object?> row) {
    return OfficerRecord(
      idPolicia: row['id_policia'] as int,
      idUsuario: row['id_usuario'] as int,
      numeroPlaca: row['numero_placa'] as String,
      grado: row['grado'] as String,
      nombres: row['nombres'] as String,
      apellidos: row['apellidos'] as String,
      unidad: row['unidad'] as String,
      sigla: row['sigla'] as String,
      ci: row['ci'] as String,
      username: row['nombre_usuario'] as String,
      estadoPolicia: row['estado_policia'] as int,
      estadoUsuario: row['estado_usuario'] as int,
    );
  }
}
