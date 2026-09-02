import '../database/app_database.dart';
import '../database/dao/user_dao.dart';

class UserRepository {
  const UserRepository(this._database);

  final AppDatabase _database;

  Future<int> createUser({
    required String username,
    required String passwordHash,
    required String role,
    DateTime? now,
  }) async {
    final db = await _database.instance;
    final timestamp = (now ?? DateTime.now()).toIso8601String();
    return UserDao(db).insert({
      'nombre_usuario': username,
      'contrasena_hash': passwordHash,
      'rol': role,
      'estado': 1,
      'fecha_creacion': timestamp,
      'fecha_modificacion': timestamp,
    });
  }

  Future<int> countAdmins() async {
    final db = await _database.instance;
    return UserDao(db).countAdmins();
  }

  Future<Map<String, Object?>?> findActiveByUsername(String username) async {
    final db = await _database.instance;
    return UserDao(db).findActiveByUsername(username);
  }

  Future<Map<String, Object?>?> findByUsername(String username) async {
    final db = await _database.instance;
    return UserDao(db).findByUsername(username);
  }

  Future<void> updatePasswordHash({
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
      throw StateError('No se pudo actualizar la contrasena del usuario.');
    }
  }
}
