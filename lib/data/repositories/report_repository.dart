import '../database/app_database.dart';
import '../database/dao/report_dao.dart';

class FinalizeReportInput {
  const FinalizeReportInput({
    required this.idPolicia,
    required this.gestion,
    required this.epi,
    this.fechaHoraLlegada,
    this.fechaHoraHecho,
    this.naturaleza,
    this.lugar,
    this.latitud,
    this.longitud,
    this.denuncianteNombre,
    this.denuncianteDocumento,
    this.denuncianteContacto,
    this.descripcion,
    this.condicionesClimaticas,
    this.vehiculosMovidos,
    this.protagonistasPresentes,
    this.testigos,
    this.efectosPersonales,
    this.rutaCroquis,
    this.rutaPdf,
    this.conductores = const [],
    this.vehiculos = const [],
    this.personas = const [],
    this.fotografias = const [],
  });

  final int idPolicia;
  final int gestion;
  final String epi;
  final DateTime? fechaHoraLlegada;
  final DateTime? fechaHoraHecho;
  final String? naturaleza;
  final String? lugar;
  final double? latitud;
  final double? longitud;
  final String? denuncianteNombre;
  final String? denuncianteDocumento;
  final String? denuncianteContacto;
  final String? descripcion;
  final String? condicionesClimaticas;
  final bool? vehiculosMovidos;
  final bool? protagonistasPresentes;
  final String? testigos;
  final String? efectosPersonales;
  final String? rutaCroquis;
  final String? rutaPdf;
  final List<DriverInput> conductores;
  final List<VehicleInput> vehiculos;
  final List<PersonInput> personas;
  final List<PhotoInput> fotografias;
}

class DriverInput {
  const DriverInput({
    required this.nombreCompleto,
    this.edad,
    this.licencia,
    this.categoria,
    this.domicilio,
    this.zona,
    this.contactos,
    this.condicionEntrega,
  });

  final String nombreCompleto;
  final int? edad;
  final String? licencia;
  final String? categoria;
  final String? domicilio;
  final String? zona;
  final String? contactos;
  final String? condicionEntrega;
}

class VehicleInput {
  const VehicleInput({
    this.driverIndex,
    this.placa,
    this.marca,
    this.color,
    this.tipo,
    this.servicio,
  });

  final int? driverIndex;
  final String? placa;
  final String? marca;
  final String? color;
  final String? tipo;
  final String? servicio;
}

class PersonInput {
  const PersonInput({
    required this.nombre,
    required this.tipo,
    this.edad,
    this.lugarEvacuacion,
  });

  final String nombre;
  final String tipo;
  final int? edad;
  final String? lugarEvacuacion;
}

class PhotoInput {
  const PhotoInput({
    required this.ruta,
    required this.tipo,
    this.descripcion,
  });

  final String ruta;
  final String tipo;
  final String? descripcion;
}

class FinalizedReport {
  const FinalizedReport({
    required this.idInforme,
    required this.gestion,
    required this.correlativo,
    required this.numeroCaso,
  });

  final int idInforme;
  final int gestion;
  final int correlativo;
  final String numeroCaso;
}

class ReportRepository {
  const ReportRepository(this._database);

  final AppDatabase _database;

  Future<FinalizedReport> finalizeReport(
    FinalizeReportInput input, {
    DateTime? now,
  }) {
    return _database.transaction((transaction) async {
      final dao = ReportDao(transaction);
      final timestamp = (now ?? DateTime.now()).toIso8601String();
      final correlativo = await dao.nextCorrelativo(input.gestion);
      final numeroCaso = formatCaseNumber(input.gestion, correlativo);

      final idInforme = await dao.insertReport({
        'id_policia': input.idPolicia,
        'gestion': input.gestion,
        'correlativo': correlativo,
        'numero_caso': numeroCaso,
        'epi': input.epi,
        'fecha_hora_llegada': input.fechaHoraLlegada?.toIso8601String(),
        'fecha_hora_hecho': input.fechaHoraHecho?.toIso8601String(),
        'naturaleza': input.naturaleza,
        'lugar': input.lugar,
        'latitud': input.latitud,
        'longitud': input.longitud,
        'denunciante_nombre': input.denuncianteNombre,
        'denunciante_documento': input.denuncianteDocumento,
        'denunciante_contacto': input.denuncianteContacto,
        'descripcion': input.descripcion,
        'condiciones_climaticas': input.condicionesClimaticas,
        'vehiculos_movidos': _boolToInt(input.vehiculosMovidos),
        'protagonistas_presentes': _boolToInt(input.protagonistasPresentes),
        'testigos': input.testigos,
        'efectos_personales': input.efectosPersonales,
        'ruta_croquis': input.rutaCroquis,
        'ruta_pdf': input.rutaPdf,
        'estado': 1,
        'fecha_creacion': timestamp,
        'fecha_modificacion': timestamp,
      });

      final driverIds = <int>[];
      for (final conductor in input.conductores) {
        driverIds.add(
          await dao.insertDriver({
            'id_informe': idInforme,
            'nombre_completo': conductor.nombreCompleto,
            'edad': conductor.edad,
            'licencia': conductor.licencia,
            'categoria': conductor.categoria,
            'domicilio': conductor.domicilio,
            'zona': conductor.zona,
            'contactos': conductor.contactos,
            'condicion_entrega': conductor.condicionEntrega,
            'fecha_creacion': timestamp,
          }),
        );
      }

      for (final vehiculo in input.vehiculos) {
        final driverIndex = vehiculo.driverIndex;
        final idConductor = driverIndex == null ? null : driverIds[driverIndex];
        await dao.insertVehicle({
          'id_informe': idInforme,
          'id_conductor': idConductor,
          'placa': vehiculo.placa,
          'marca': vehiculo.marca,
          'color': vehiculo.color,
          'tipo': vehiculo.tipo,
          'servicio': vehiculo.servicio,
          'fecha_creacion': timestamp,
        });
      }

      for (final persona in input.personas) {
        await dao.insertPerson({
          'id_informe': idInforme,
          'nombre': persona.nombre,
          'edad': persona.edad,
          'tipo': persona.tipo,
          'lugar_evacuacion': persona.lugarEvacuacion,
          'fecha_creacion': timestamp,
        });
      }

      for (final fotografia in input.fotografias) {
        await dao.insertPhoto({
          'id_informe': idInforme,
          'ruta': fotografia.ruta,
          'tipo': fotografia.tipo,
          'descripcion': fotografia.descripcion,
          'fecha_creacion': timestamp,
        });
      }

      return FinalizedReport(
        idInforme: idInforme,
        gestion: input.gestion,
        correlativo: correlativo,
        numeroCaso: numeroCaso,
      );
    });
  }

  Future<List<Map<String, Object?>>> findActiveReports() async {
    final db = await _database.instance;
    return ReportDao(db).findActiveReports();
  }

  Future<void> inactivateReport({
    required int idInforme,
    DateTime? now,
  }) async {
    final db = await _database.instance;
    final updatedRows = await ReportDao(db).inactivateReport(
      idInforme,
      (now ?? DateTime.now()).toIso8601String(),
    );
    if (updatedRows != 1) {
      throw StateError('No se pudo inactivar el informe $idInforme.');
    }
  }

  static String formatCaseNumber(int gestion, int correlativo) {
    return '$gestion-${correlativo.toString().padLeft(6, '0')}';
  }

  static int? _boolToInt(bool? value) {
    if (value == null) {
      return null;
    }
    return value ? 1 : 0;
  }
}
