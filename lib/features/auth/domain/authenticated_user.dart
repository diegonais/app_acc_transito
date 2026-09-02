import 'app_role.dart';

class PoliceProfile {
  const PoliceProfile({
    required this.idPolicia,
    required this.numeroPlaca,
    required this.grado,
    required this.nombres,
    required this.apellidos,
    required this.unidad,
    required this.sigla,
    required this.ci,
  });

  final int idPolicia;
  final String numeroPlaca;
  final String grado;
  final String nombres;
  final String apellidos;
  final String unidad;
  final String sigla;
  final String ci;

  String get nombreCompleto => '$nombres $apellidos'.trim();

  String get qrDisplayData => '$nombreCompleto\n$grado\n$numeroPlaca\n$unidad';
}

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.idUsuario,
    required this.username,
    required this.role,
    this.policeProfile,
  });

  final int idUsuario;
  final String username;
  final AppRole role;
  final PoliceProfile? policeProfile;

  bool get isAdmin => role == AppRole.admin;
  bool get isPolice => role == AppRole.police;

  int get requiredPoliceId {
    final profile = policeProfile;
    if (profile == null) {
      throw StateError('La sesion no tiene datos de policia.');
    }
    return profile.idPolicia;
  }
}
