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

  Future<Map<String, Object?>?> findByUsername(String username) async {
    final rows = await _db.query(
      'usuarios',
      where: 'nombre_usuario = ?',
      whereArgs: [username],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> countAdmins() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM usuarios WHERE rol = ?',
      ['ADMIN'],
    );
    return rows.single['total'] as int;
  }

  Future<int> updatePasswordHash(
    int idUsuario,
    String passwordHash,
    String modifiedAt,
  ) {
    return _db.update(
      'usuarios',
      {
        'contrasena_hash': passwordHash,
        'fecha_modificacion': modifiedAt,
      },
      where: 'id_usuario = ?',
      whereArgs: [idUsuario],
    );
  }
}
