import 'package:sqflite/sqflite.dart';

class PoliceDao {
  const PoliceDao(this._db);

  final DatabaseExecutor _db;

  Future<int> insert(Map<String, Object?> values) {
    return _db.insert('policias', values);
  }

  Future<Map<String, Object?>?> findById(int idPolicia) async {
    final rows = await _db.query(
      'policias',
      where: 'id_policia = ?',
      whereArgs: [idPolicia],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}
