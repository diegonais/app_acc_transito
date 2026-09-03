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

  Future<List<Map<String, Object?>>> findAllWithUsers() {
    return _db.rawQuery('''
SELECT
  p.id_policia,
  p.id_usuario,
  p.numero_placa,
  p.grado,
  p.nombres,
  p.apellidos,
  p.unidad,
  p.sigla,
  p.ci,
  p.estado AS estado_policia,
  p.fecha_creacion,
  p.fecha_modificacion,
  u.nombre_usuario,
  u.estado AS estado_usuario
FROM policias p
INNER JOIN usuarios u ON u.id_usuario = p.id_usuario
ORDER BY p.apellidos COLLATE NOCASE, p.nombres COLLATE NOCASE
''');
  }

  Future<Map<String, Object?>?> findByPlate(String numeroPlaca) async {
    final rows = await _db.query(
      'policias',
      where: 'numero_placa = ?',
      whereArgs: [numeroPlaca],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> findByPlateExceptId(
    String numeroPlaca,
    int idPolicia,
  ) async {
    final rows = await _db.query(
      'policias',
      where: 'numero_placa = ? AND id_policia <> ?',
      whereArgs: [numeroPlaca, idPolicia],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> findActiveByUserId(int idUsuario) async {
    final rows = await _db.query(
      'policias',
      where: 'id_usuario = ? AND estado = ?',
      whereArgs: [idUsuario, 1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateAdministrativeData(
    int idPolicia,
    Map<String, Object?> values,
  ) {
    return _db.update(
      'policias',
      values,
      where: 'id_policia = ?',
      whereArgs: [idPolicia],
    );
  }

  Future<int> updateStatus(int idPolicia, int estado, String modifiedAt) {
    return _db.update(
      'policias',
      {
        'estado': estado,
        'fecha_modificacion': modifiedAt,
      },
      where: 'id_policia = ?',
      whereArgs: [idPolicia],
    );
  }
}
