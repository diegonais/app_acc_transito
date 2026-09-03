import '../database/app_database.dart';
import '../database/dao/report_dao.dart';
import '../../services/media/evidence_photo.dart';

class ReportValidationException implements Exception {
  const ReportValidationException(this.messages);

  final List<String> messages;

  @override
  String toString() => messages.join('\n');
}

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

  DriverInput copyWith({
    String? nombreCompleto,
    int? edad,
    String? licencia,
    String? categoria,
    String? domicilio,
    String? zona,
    String? contactos,
    String? condicionEntrega,
  }) {
    return DriverInput(
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      edad: edad ?? this.edad,
      licencia: licencia ?? this.licencia,
      categoria: categoria ?? this.categoria,
      domicilio: domicilio ?? this.domicilio,
      zona: zona ?? this.zona,
      contactos: contactos ?? this.contactos,
      condicionEntrega: condicionEntrega ?? this.condicionEntrega,
    );
  }
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

  VehicleInput copyWith({
    int? driverIndex,
    bool clearDriverIndex = false,
    String? placa,
    String? marca,
    String? color,
    String? tipo,
    String? servicio,
  }) {
    return VehicleInput(
      driverIndex: clearDriverIndex ? null : driverIndex ?? this.driverIndex,
      placa: placa ?? this.placa,
      marca: marca ?? this.marca,
      color: color ?? this.color,
      tipo: tipo ?? this.tipo,
      servicio: servicio ?? this.servicio,
    );
  }
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

  PersonInput copyWith({
    String? nombre,
    String? tipo,
    int? edad,
    String? lugarEvacuacion,
  }) {
    return PersonInput(
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      edad: edad ?? this.edad,
      lugarEvacuacion: lugarEvacuacion ?? this.lugarEvacuacion,
    );
  }
}

class PhotoInput {
  const PhotoInput({
    required this.ruta,
    required this.tipo,
    this.descripcion,
  });

  final String ruta;
  final EvidencePhotoCategory tipo;
  final String? descripcion;

  PhotoInput copyWith({
    String? ruta,
    EvidencePhotoCategory? tipo,
    String? descripcion,
  }) {
    return PhotoInput(
      ruta: ruta ?? this.ruta,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
    );
  }
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

class ReportRecord {
  const ReportRecord({
    required this.idInforme,
    required this.idPolicia,
    required this.gestion,
    required this.correlativo,
    required this.numeroCaso,
    required this.epi,
    required this.estado,
    required this.fechaCreacion,
    required this.fechaModificacion,
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

  final int idInforme;
  final int idPolicia;
  final int gestion;
  final int correlativo;
  final String numeroCaso;
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
  final int estado;
  final DateTime fechaCreacion;
  final DateTime fechaModificacion;
  final List<DriverRecord> conductores;
  final List<VehicleRecord> vehiculos;
  final List<PersonRecord> personas;
  final List<PhotoRecord> fotografias;

  bool get isActive => estado == 1;

  ReportRecord copyWith({
    List<DriverRecord>? conductores,
    List<VehicleRecord>? vehiculos,
    List<PersonRecord>? personas,
    List<PhotoRecord>? fotografias,
  }) {
    return ReportRecord(
      idInforme: idInforme,
      idPolicia: idPolicia,
      gestion: gestion,
      correlativo: correlativo,
      numeroCaso: numeroCaso,
      epi: epi,
      fechaHoraLlegada: fechaHoraLlegada,
      fechaHoraHecho: fechaHoraHecho,
      naturaleza: naturaleza,
      lugar: lugar,
      latitud: latitud,
      longitud: longitud,
      denuncianteNombre: denuncianteNombre,
      denuncianteDocumento: denuncianteDocumento,
      denuncianteContacto: denuncianteContacto,
      descripcion: descripcion,
      condicionesClimaticas: condicionesClimaticas,
      vehiculosMovidos: vehiculosMovidos,
      protagonistasPresentes: protagonistasPresentes,
      testigos: testigos,
      efectosPersonales: efectosPersonales,
      rutaCroquis: rutaCroquis,
      rutaPdf: rutaPdf,
      estado: estado,
      fechaCreacion: fechaCreacion,
      fechaModificacion: fechaModificacion,
      conductores: conductores ?? this.conductores,
      vehiculos: vehiculos ?? this.vehiculos,
      personas: personas ?? this.personas,
      fotografias: fotografias ?? this.fotografias,
    );
  }
}

class DriverRecord {
  const DriverRecord({
    required this.idConductor,
    required this.nombreCompleto,
    this.edad,
    this.licencia,
    this.categoria,
    this.domicilio,
    this.zona,
    this.contactos,
    this.condicionEntrega,
  });

  final int idConductor;
  final String nombreCompleto;
  final int? edad;
  final String? licencia;
  final String? categoria;
  final String? domicilio;
  final String? zona;
  final String? contactos;
  final String? condicionEntrega;
}

class VehicleRecord {
  const VehicleRecord({
    required this.idVehiculo,
    this.idConductor,
    this.placa,
    this.marca,
    this.color,
    this.tipo,
    this.servicio,
  });

  final int idVehiculo;
  final int? idConductor;
  final String? placa;
  final String? marca;
  final String? color;
  final String? tipo;
  final String? servicio;
}

class PersonRecord {
  const PersonRecord({
    required this.idPersona,
    required this.nombre,
    required this.tipo,
    this.edad,
    this.lugarEvacuacion,
  });

  final int idPersona;
  final String nombre;
  final String tipo;
  final int? edad;
  final String? lugarEvacuacion;
}

class PhotoRecord {
  const PhotoRecord({
    required this.idFotografia,
    required this.ruta,
    required this.tipo,
    this.descripcion,
  });

  final int idFotografia;
  final String ruta;
  final EvidencePhotoCategory tipo;
  final String? descripcion;
}

class ReportQueryFilter {
  const ReportQueryFilter({
    this.idPolicia,
    this.from,
    this.to,
  });

  final int? idPolicia;
  final DateTime? from;
  final DateTime? to;

  ReportQueryFilter copyWith({
    int? idPolicia,
    bool clearPolice = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) {
    return ReportQueryFilter(
      idPolicia: clearPolice ? null : idPolicia ?? this.idPolicia,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
    );
  }

  bool get isEmpty => idPolicia == null && from == null && to == null;
}

class PoliceReportCount {
  const PoliceReportCount({
    required this.idPolicia,
    required this.grado,
    required this.nombres,
    required this.apellidos,
    required this.numeroPlaca,
    required this.total,
  });

  final int idPolicia;
  final String grado;
  final String nombres;
  final String apellidos;
  final String numeroPlaca;
  final int total;

  String get nombreCompleto => '$nombres $apellidos'.trim();
  String get displayName => '$grado $nombreCompleto - $numeroPlaca';
}

class MonthlyReportCount {
  const MonthlyReportCount({
    required this.gestion,
    required this.mes,
    required this.total,
  });

  final int gestion;
  final int mes;
  final int total;
}

class DashboardStats {
  const DashboardStats({
    required this.totalActiveReports,
    required this.activePoliceCount,
    required this.reportsToday,
    required this.reportsThisMonth,
    required this.reportsBySelectedDate,
    required this.reportsByPolice,
    required this.reportsByMonth,
  });

  final int totalActiveReports;
  final int activePoliceCount;
  final int reportsToday;
  final int reportsThisMonth;
  final int reportsBySelectedDate;
  final List<PoliceReportCount> reportsByPolice;
  final List<MonthlyReportCount> reportsByMonth;
}

typedef PersistPhotosForCase = Future<List<PhotoInput>> Function({
  required String numeroCaso,
  required List<PhotoInput> photos,
});

typedef CleanupPhotos = Future<void> Function(List<PhotoInput> photos);

class ReportRepository {
  const ReportRepository(this._database);

  final AppDatabase _database;

  Future<FinalizedReport> finalizeReport(
    FinalizeReportInput input, {
    DateTime? now,
    PersistPhotosForCase? persistPhotosForCase,
    CleanupPhotos? cleanupPersistedPhotos,
  }) async {
    _validateInput(input);
    var persistedPhotos = <PhotoInput>[];
    try {
      return await _database.transaction((transaction) async {
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
          final idConductor =
              driverIndex == null ? null : driverIds[driverIndex];
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

        persistedPhotos = input.fotografias.isEmpty
            ? const []
            : persistPhotosForCase == null
                ? input.fotografias
                : await persistPhotosForCase(
                    numeroCaso: numeroCaso,
                    photos: input.fotografias,
                  );

        for (final fotografia in persistedPhotos) {
          await dao.insertPhoto({
            'id_informe': idInforme,
            'ruta': fotografia.ruta,
            'tipo': fotografia.tipo.databaseValue,
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
    } catch (_) {
      if (persistedPhotos.isNotEmpty && cleanupPersistedPhotos != null) {
        await cleanupPersistedPhotos(persistedPhotos);
      }
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> findActiveReports() async {
    final db = await _database.instance;
    return ReportDao(db).findActiveReports();
  }

  Future<List<ReportRecord>> listActiveReportsForAdmin() async {
    return queryActiveReportsForAdmin();
  }

  Future<List<ReportRecord>> queryActiveReportsForAdmin({
    ReportQueryFilter filter = const ReportQueryFilter(),
  }) async {
    final db = await _database.instance;
    final rows = await ReportDao(db).findActiveReportsFiltered(
      idPolicia: filter.idPolicia,
      from: filter.from,
      to: filter.to,
    );
    return rows.map(_mapReport).toList(growable: false);
  }

  Future<List<ReportRecord>> listActiveReportsForPolice(int idPolicia) async {
    return queryActiveReportsForPolice(idPolicia: idPolicia);
  }

  Future<List<ReportRecord>> queryActiveReportsForPolice({
    required int idPolicia,
    ReportQueryFilter filter = const ReportQueryFilter(),
  }) async {
    final db = await _database.instance;
    final rows = await ReportDao(db).findActiveReportsFiltered(
      idPolicia: idPolicia,
      from: filter.from,
      to: filter.to,
    );
    return rows.map(_mapReport).toList(growable: false);
  }

  Future<ReportRecord?> findActiveReportDetail(int idInforme) async {
    final db = await _database.instance;
    final dao = ReportDao(db);
    final report = await dao.findActiveById(idInforme);
    if (report == null) {
      return null;
    }
    return _mapReport(report).copyWith(
      conductores: (await dao.findDrivers(idInforme)).map(_mapDriver).toList(),
      vehiculos: (await dao.findVehicles(idInforme)).map(_mapVehicle).toList(),
      personas: (await dao.findPeople(idInforme)).map(_mapPerson).toList(),
      fotografias: (await dao.findPhotos(idInforme)).map(_mapPhoto).toList(),
    );
  }

  Future<ReportRecord?> findActiveReportDetailForPolice({
    required int idInforme,
    required int idPolicia,
  }) async {
    final db = await _database.instance;
    final dao = ReportDao(db);
    final report = await dao.findActiveByIdForPolice(idInforme, idPolicia);
    if (report == null) {
      return null;
    }
    return _mapReport(report).copyWith(
      conductores: (await dao.findDrivers(idInforme)).map(_mapDriver).toList(),
      vehiculos: (await dao.findVehicles(idInforme)).map(_mapVehicle).toList(),
      personas: (await dao.findPeople(idInforme)).map(_mapPerson).toList(),
      fotografias: (await dao.findPhotos(idInforme)).map(_mapPhoto).toList(),
    );
  }

  Future<DashboardStats> loadAdminDashboard({
    required DateTime referenceDate,
    DateTime? selectedDate,
  }) async {
    final db = await _database.instance;
    final dao = ReportDao(db);
    final todayRange = _dayRange(referenceDate);
    final monthRange = _monthRange(referenceDate);
    final selectedRange = _dayRange(selectedDate ?? referenceDate);

    return DashboardStats(
      totalActiveReports: await dao.countActiveReports(),
      activePoliceCount: await dao.countActivePolice(),
      reportsToday: await dao.countActiveReportsFromTo(
        from: todayRange.$1,
        to: todayRange.$2,
      ),
      reportsThisMonth: await dao.countActiveReportsFromTo(
        from: monthRange.$1,
        to: monthRange.$2,
      ),
      reportsBySelectedDate: await dao.countActiveReportsFromTo(
        from: selectedRange.$1,
        to: selectedRange.$2,
      ),
      reportsByPolice: (await dao.countActiveReportsByPolice())
          .map(_mapPoliceReportCount)
          .toList(growable: false),
      reportsByMonth: (await dao.countActiveReportsByMonth())
          .map(_mapMonthlyReportCount)
          .toList(growable: false),
    );
  }

  Future<DashboardStats> loadPoliceDashboard({
    required int idPolicia,
    required DateTime referenceDate,
    DateTime? selectedDate,
  }) async {
    final db = await _database.instance;
    final dao = ReportDao(db);
    final todayRange = _dayRange(referenceDate);
    final monthRange = _monthRange(referenceDate);
    final selectedRange = _dayRange(selectedDate ?? referenceDate);

    return DashboardStats(
      totalActiveReports: await dao.countActiveReports(idPolicia: idPolicia),
      activePoliceCount: 0,
      reportsToday: await dao.countActiveReportsFromTo(
        from: todayRange.$1,
        to: todayRange.$2,
        idPolicia: idPolicia,
      ),
      reportsThisMonth: await dao.countActiveReportsFromTo(
        from: monthRange.$1,
        to: monthRange.$2,
        idPolicia: idPolicia,
      ),
      reportsBySelectedDate: await dao.countActiveReportsFromTo(
        from: selectedRange.$1,
        to: selectedRange.$2,
        idPolicia: idPolicia,
      ),
      reportsByPolice: const [],
      reportsByMonth: (await dao.countActiveReportsByMonth(
        idPolicia: idPolicia,
      ))
          .map(_mapMonthlyReportCount)
          .toList(growable: false),
    );
  }

  Future<List<PoliceReportCount>> listPoliceReportCounts() async {
    final db = await _database.instance;
    return (await ReportDao(db).countActiveReportsByPolice())
        .map(_mapPoliceReportCount)
        .toList(growable: false);
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

  static void _validateInput(FinalizeReportInput input) {
    final messages = <String>[];
    void requiredText(String label, String? value) {
      if ((value ?? '').trim().isEmpty) {
        messages.add('Debe ingresar $label.');
      }
    }

    if (input.idPolicia <= 0) {
      messages.add('El informe debe asociarse a un policia valido.');
    }
    if (input.gestion < 2000) {
      messages.add('La gestion del informe no es valida.');
    }
    requiredText('EPI / Estacion Policial Integral', input.epi);
    if (input.fechaHoraLlegada == null) {
      messages.add('Debe ingresar fecha y hora de llegada.');
    }
    if (input.fechaHoraHecho == null) {
      messages.add('Debe ingresar fecha y hora del hecho.');
    }
    requiredText('naturaleza', input.naturaleza);
    requiredText('lugar', input.lugar);
    requiredText('denunciante', input.denuncianteNombre);
    requiredText('contacto del denunciante', input.denuncianteContacto);
    requiredText('descripcion', input.descripcion);
    requiredText('condiciones climaticas', input.condicionesClimaticas);
    if (input.vehiculosMovidos == null) {
      messages.add('Debe indicar si los vehiculos fueron movidos.');
    }
    if (input.protagonistasPresentes == null) {
      messages.add('Debe indicar si los protagonistas estan presentes.');
    }
    requiredText('testigos', input.testigos);
    requiredText('efectos personales', input.efectosPersonales);

    for (final (index, conductor) in input.conductores.indexed) {
      requiredText(
          'nombre del conductor ${index + 1}', conductor.nombreCompleto);
      if (conductor.edad == null) {
        messages.add('Debe ingresar edad del conductor ${index + 1}.');
      } else if (conductor.edad! < 0) {
        messages.add('La edad del conductor ${index + 1} no es valida.');
      }
      requiredText('licencia del conductor ${index + 1}', conductor.licencia);
      requiredText('categoria del conductor ${index + 1}', conductor.categoria);
      requiredText('domicilio del conductor ${index + 1}', conductor.domicilio);
      requiredText('zona del conductor ${index + 1}', conductor.zona);
      requiredText('contactos del conductor ${index + 1}', conductor.contactos);
    }
    for (final (index, vehiculo) in input.vehiculos.indexed) {
      requiredText('placa del vehiculo ${index + 1}', vehiculo.placa);
      requiredText('marca del vehiculo ${index + 1}', vehiculo.marca);
      requiredText('color del vehiculo ${index + 1}', vehiculo.color);
      requiredText('tipo del vehiculo ${index + 1}', vehiculo.tipo);
      requiredText('servicio del vehiculo ${index + 1}', vehiculo.servicio);
      final driverIndex = vehiculo.driverIndex;
      if (driverIndex != null &&
          (driverIndex < 0 || driverIndex >= input.conductores.length)) {
        messages
            .add('El vehiculo ${index + 1} referencia un conductor invalido.');
      }
    }
    for (final (index, persona) in input.personas.indexed) {
      requiredText(
          'nombre de la persona involucrada ${index + 1}', persona.nombre);
      if (persona.tipo != 'HERIDO' && persona.tipo != 'FALLECIDO') {
        messages.add('El tipo de persona ${index + 1} no es valido.');
      }
      if (persona.edad == null) {
        messages.add('Debe ingresar edad de la persona ${index + 1}.');
      } else if (persona.edad! < 0) {
        messages.add('La edad de la persona ${index + 1} no es valida.');
      }
    }
    for (final (index, fotografia) in input.fotografias.indexed) {
      requiredText('ruta de fotografia ${index + 1}', fotografia.ruta);
    }

    if (messages.isNotEmpty) {
      throw ReportValidationException(messages);
    }
  }

  static ReportRecord _mapReport(Map<String, Object?> row) {
    return ReportRecord(
      idInforme: row['id_informe']! as int,
      idPolicia: row['id_policia']! as int,
      gestion: row['gestion']! as int,
      correlativo: row['correlativo']! as int,
      numeroCaso: row['numero_caso']! as String,
      epi: row['epi']! as String,
      fechaHoraLlegada: _parseOptionalDate(row['fecha_hora_llegada']),
      fechaHoraHecho: _parseOptionalDate(row['fecha_hora_hecho']),
      naturaleza: row['naturaleza'] as String?,
      lugar: row['lugar'] as String?,
      latitud: (row['latitud'] as num?)?.toDouble(),
      longitud: (row['longitud'] as num?)?.toDouble(),
      denuncianteNombre: row['denunciante_nombre'] as String?,
      denuncianteDocumento: row['denunciante_documento'] as String?,
      denuncianteContacto: row['denunciante_contacto'] as String?,
      descripcion: row['descripcion'] as String?,
      condicionesClimaticas: row['condiciones_climaticas'] as String?,
      vehiculosMovidos: _intToBool(row['vehiculos_movidos']),
      protagonistasPresentes: _intToBool(row['protagonistas_presentes']),
      testigos: row['testigos'] as String?,
      efectosPersonales: row['efectos_personales'] as String?,
      rutaCroquis: row['ruta_croquis'] as String?,
      rutaPdf: row['ruta_pdf'] as String?,
      estado: row['estado']! as int,
      fechaCreacion: DateTime.parse(row['fecha_creacion']! as String),
      fechaModificacion: DateTime.parse(row['fecha_modificacion']! as String),
    );
  }

  static DriverRecord _mapDriver(Map<String, Object?> row) {
    return DriverRecord(
      idConductor: row['id_conductor']! as int,
      nombreCompleto: row['nombre_completo']! as String,
      edad: row['edad'] as int?,
      licencia: row['licencia'] as String?,
      categoria: row['categoria'] as String?,
      domicilio: row['domicilio'] as String?,
      zona: row['zona'] as String?,
      contactos: row['contactos'] as String?,
      condicionEntrega: row['condicion_entrega'] as String?,
    );
  }

  static VehicleRecord _mapVehicle(Map<String, Object?> row) {
    return VehicleRecord(
      idVehiculo: row['id_vehiculo']! as int,
      idConductor: row['id_conductor'] as int?,
      placa: row['placa'] as String?,
      marca: row['marca'] as String?,
      color: row['color'] as String?,
      tipo: row['tipo'] as String?,
      servicio: row['servicio'] as String?,
    );
  }

  static PersonRecord _mapPerson(Map<String, Object?> row) {
    return PersonRecord(
      idPersona: row['id_persona']! as int,
      nombre: row['nombre']! as String,
      edad: row['edad'] as int?,
      tipo: row['tipo']! as String,
      lugarEvacuacion: row['lugar_evacuacion'] as String?,
    );
  }

  static PhotoRecord _mapPhoto(Map<String, Object?> row) {
    return PhotoRecord(
      idFotografia: row['id_fotografia']! as int,
      ruta: row['ruta']! as String,
      tipo: EvidencePhotoCategory.fromDatabase(row['tipo']! as String),
      descripcion: row['descripcion'] as String?,
    );
  }

  static PoliceReportCount _mapPoliceReportCount(Map<String, Object?> row) {
    return PoliceReportCount(
      idPolicia: row['id_policia']! as int,
      grado: row['grado']! as String,
      nombres: row['nombres']! as String,
      apellidos: row['apellidos']! as String,
      numeroPlaca: row['numero_placa']! as String,
      total: row['total']! as int,
    );
  }

  static MonthlyReportCount _mapMonthlyReportCount(Map<String, Object?> row) {
    return MonthlyReportCount(
      gestion: row['gestion']! as int,
      mes: row['mes']! as int,
      total: row['total']! as int,
    );
  }

  static (DateTime, DateTime) _dayRange(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return (start, start.add(const Duration(days: 1)));
  }

  static (DateTime, DateTime) _monthRange(DateTime date) {
    final start = DateTime(date.year, date.month);
    return (start, DateTime(date.year, date.month + 1));
  }

  static int? _boolToInt(bool? value) {
    if (value == null) {
      return null;
    }
    return value ? 1 : 0;
  }

  static bool? _intToBool(Object? value) {
    if (value == null) {
      return null;
    }
    return value == 1;
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }
}
