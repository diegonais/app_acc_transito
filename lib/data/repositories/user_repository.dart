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

  Future<Map<String, Object?>?> findActiveByUsername(String username) async {
    final db = await _database.instance;
    return UserDao(db).findActiveByUsername(username);
  }
}
