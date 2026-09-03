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
    return findActiveReportsFiltered();
  }

  Future<List<Map<String, Object?>>> findActiveReportsByPolice(
    int idPolicia,
  ) {
    return findActiveReportsFiltered(idPolicia: idPolicia);
  }

  Future<List<Map<String, Object?>>> findActiveReportsFiltered({
    int? idPolicia,
    DateTime? from,
    DateTime? to,
  }) {
    final where = <String>['estado = ?'];
    final args = <Object?>[1];
    if (idPolicia != null) {
      where.add('id_policia = ?');
      args.add(idPolicia);
    }
    if (from != null) {
      where.add('fecha_hora_hecho >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('fecha_hora_hecho < ?');
      args.add(to.toIso8601String());
    }
    return _db.query(
      'informes',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'fecha_hora_hecho DESC, gestion DESC, correlativo DESC',
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

  Future<Map<String, Object?>?> findActiveByIdForPolice(
    int idInforme,
    int idPolicia,
  ) async {
    final rows = await _db.query(
      'informes',
      where: 'id_informe = ? AND id_policia = ? AND estado = ?',
      whereArgs: [idInforme, idPolicia, 1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> countActiveReports({int? idPolicia}) async {
    final where = <String>['estado = ?'];
    final args = <Object?>[1];
    if (idPolicia != null) {
      where.add('id_policia = ?');
      args.add(idPolicia);
    }
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM informes WHERE ${where.join(' AND ')}',
      args,
    );
    return rows.first['total']! as int;
  }

  Future<int> countActiveReportsFromTo({
    required DateTime from,
    required DateTime to,
    int? idPolicia,
  }) async {
    final where = <String>[
      'estado = ?',
      'fecha_hora_hecho >= ?',
      'fecha_hora_hecho < ?',
    ];
    final args = <Object?>[
      1,
      from.toIso8601String(),
      to.toIso8601String(),
    ];
    if (idPolicia != null) {
      where.add('id_policia = ?');
      args.add(idPolicia);
    }
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM informes WHERE ${where.join(' AND ')}',
      args,
    );
    return rows.first['total']! as int;
  }

  Future<int> countActivePolice() async {
    final rows = await _db.rawQuery('''
SELECT COUNT(*) AS total
FROM policias p
INNER JOIN usuarios u ON u.id_usuario = p.id_usuario
WHERE p.estado = ? AND u.estado = ?
''', [1, 1]);
    return rows.first['total']! as int;
  }

  Future<List<Map<String, Object?>>> countActiveReportsByPolice() {
    return _db.rawQuery('''
SELECT
  p.id_policia,
  p.grado,
  p.nombres,
  p.apellidos,
  p.numero_placa,
  COUNT(i.id_informe) AS total
FROM policias p
INNER JOIN usuarios u ON u.id_usuario = p.id_usuario
LEFT JOIN informes i
  ON i.id_policia = p.id_policia
  AND i.estado = 1
WHERE p.estado = ? AND u.estado = ?
GROUP BY
  p.id_policia,
  p.grado,
  p.nombres,
  p.apellidos,
  p.numero_placa
ORDER BY p.apellidos COLLATE NOCASE, p.nombres COLLATE NOCASE
''', [1, 1]);
  }

  Future<List<Map<String, Object?>>> countActiveReportsByMonth({
    int? idPolicia,
  }) {
    final where = <String>['estado = ?', 'fecha_hora_hecho IS NOT NULL'];
    final args = <Object?>[1];
    if (idPolicia != null) {
      where.add('id_policia = ?');
      args.add(idPolicia);
    }
    return _db.rawQuery('''
SELECT
  CAST(strftime('%Y', fecha_hora_hecho) AS INTEGER) AS gestion,
  CAST(strftime('%m', fecha_hora_hecho) AS INTEGER) AS mes,
  COUNT(*) AS total
FROM informes
WHERE ${where.join(' AND ')}
GROUP BY gestion, mes
ORDER BY gestion DESC, mes DESC
''', args);
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
