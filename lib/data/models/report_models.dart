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
