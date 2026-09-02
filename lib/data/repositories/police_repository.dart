import '../database/app_database.dart';
import '../database/dao/police_dao.dart';

class PoliceRepository {
  const PoliceRepository(this._database);

  final AppDatabase _database;

  Future<int> createPolice({
    required int idUsuario,
    required String numeroPlaca,
    required String grado,
    required String nombres,
    required String apellidos,
    required String unidad,
    required String sigla,
    required String ci,
    DateTime? now,
  }) async {
    final db = await _database.instance;
    final timestamp = (now ?? DateTime.now()).toIso8601String();
    return PoliceDao(db).insert({
      'id_usuario': idUsuario,
      'numero_placa': numeroPlaca,
      'grado': grado,
      'nombres': nombres,
      'apellidos': apellidos,
      'unidad': unidad,
      'sigla': sigla,
      'ci': ci,
      'estado': 1,
      'fecha_creacion': timestamp,
      'fecha_modificacion': timestamp,
    });
  }
}
