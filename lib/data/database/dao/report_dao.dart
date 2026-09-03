import 'package:sqflite/sqflite.dart';

class ReportDao {
  const ReportDao(this._db);

  final DatabaseExecutor _db;

  Future<int> nextCorrelativo(int gestion) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(correlativo), 0) + 1 AS siguiente '
      'FROM informes WHERE gestion = ?',
      [gestion],
    );
    return rows.first['siguiente']! as int;
  }

  Future<int> insertReport(Map<String, Object?> values) {
    return _db.insert('informes', values);
  }

  Future<int> insertDriver(Map<String, Object?> values) {
    return _db.insert('conductores', values);
  }

  Future<int> insertVehicle(Map<String, Object?> values) {
    return _db.insert('vehiculos', values);
  }

  Future<int> insertPerson(Map<String, Object?> values) {
    return _db.insert('personas_involucradas', values);
  }

  Future<int> insertPhoto(Map<String, Object?> values) {
    return _db.insert('fotografias', values);
  }

  Future<List<Map<String, Object?>>> findActiveReports() {
    return _db.query(
      'informes',
      where: 'estado = ?',
      whereArgs: [1],
      orderBy: 'gestion DESC, correlativo DESC',
    );
  }

  Future<List<Map<String, Object?>>> findActiveReportsByPolice(
    int idPolicia,
  ) {
    return _db.query(
      'informes',
      where: 'estado = ? AND id_policia = ?',
      whereArgs: [1, idPolicia],
      orderBy: 'gestion DESC, correlativo DESC',
    );
  }

  Future<Map<String, Object?>?> findActiveById(int idInforme) async {
    final rows = await _db.query(
      'informes',
      where: 'id_informe = ? AND estado = ?',
      whereArgs: [idInforme, 1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> findDrivers(int idInforme) {
    return _db.query(
      'conductores',
      where: 'id_informe = ?',
      whereArgs: [idInforme],
      orderBy: 'id_conductor ASC',
    );
  }

  Future<List<Map<String, Object?>>> findVehicles(int idInforme) {
    return _db.query(
      'vehiculos',
      where: 'id_informe = ?',
      whereArgs: [idInforme],
      orderBy: 'id_vehiculo ASC',
    );
  }

  Future<List<Map<String, Object?>>> findPeople(int idInforme) {
    return _db.query(
      'personas_involucradas',
      where: 'id_informe = ?',
      whereArgs: [idInforme],
      orderBy: 'id_persona ASC',
    );
  }

  Future<List<Map<String, Object?>>> findPhotos(int idInforme) {
    return _db.query(
      'fotografias',
      where: 'id_informe = ?',
      whereArgs: [idInforme],
      orderBy: 'id_fotografia ASC',
    );
  }

  Future<Map<String, Object?>?> findByCaseNumber(String numeroCaso) async {
    final rows = await _db.query(
      'informes',
      where: 'numero_caso = ?',
      whereArgs: [numeroCaso],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> inactivateReport(int idInforme, String fechaModificacion) {
    return _db.update(
      'informes',
      {
        'estado': 0,
        'fecha_modificacion': fechaModificacion,
      },
      where: 'id_informe = ? AND estado = ?',
      whereArgs: [idInforme, 1],
    );
  }
}
