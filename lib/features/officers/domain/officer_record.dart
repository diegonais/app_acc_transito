class OfficerRecord {
  const OfficerRecord({
    required this.idPolicia,
    required this.idUsuario,
    required this.numeroPlaca,
    required this.grado,
    required this.nombres,
    required this.apellidos,
    required this.unidad,
    required this.sigla,
    required this.ci,
    required this.username,
    required this.estadoPolicia,
    required this.estadoUsuario,
  });

  final int idPolicia;
  final int idUsuario;
  final String numeroPlaca;
  final String grado;
  final String nombres;
  final String apellidos;
  final String unidad;
  final String sigla;
  final String ci;
  final String username;
  final int estadoPolicia;
  final int estadoUsuario;

  bool get isActive => estadoPolicia == 1 && estadoUsuario == 1;
  String get nombreCompleto => '$nombres $apellidos'.trim();
}

class OfficerAccountInput {
  const OfficerAccountInput({
    required this.numeroPlaca,
    required this.grado,
    required this.nombres,
    required this.apellidos,
    required this.unidad,
    required this.sigla,
    required this.ci,
    required this.username,
    required this.passwordHash,
    required this.isActive,
  });

  final String numeroPlaca;
  final String grado;
  final String nombres;
  final String apellidos;
  final String unidad;
  final String sigla;
  final String ci;
  final String username;
  final String passwordHash;
  final bool isActive;
}

class OfficerUpdateInput {
  const OfficerUpdateInput({
    required this.idPolicia,
    required this.idUsuario,
    required this.numeroPlaca,
    required this.grado,
    required this.nombres,
    required this.apellidos,
    required this.unidad,
    required this.sigla,
    required this.ci,
    required this.username,
  });

  final int idPolicia;
  final int idUsuario;
  final String numeroPlaca;
  final String grado;
  final String nombres;
  final String apellidos;
  final String unidad;
  final String sigla;
  final String ci;
  final String username;
}
