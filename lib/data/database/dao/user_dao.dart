import 'package:sqflite/sqflite.dart';

class UserDao {
  const UserDao(this._db);

  final DatabaseExecutor _db;

  Future<int> insert(Map<String, Object?> values) {
    return _db.insert('usuarios', values);
  }

  Future<Map<String, Object?>?> findById(int idUsuario) async {
    final rows = await _db.query(
      'usuarios',
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> findActiveByUsername(String username) async {
    final rows = await _db.query(
      'usuarios',
      where: 'nombre_usuario = ? AND estado = ?',
      whereArgs: [username, 1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}
