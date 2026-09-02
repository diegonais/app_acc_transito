enum AppRole {
  admin('ADMIN'),
  police('POLICE');

  const AppRole(this.databaseValue);

  final String databaseValue;

  static AppRole fromDatabase(String value) {
    return AppRole.values.firstWhere(
      (role) => role.databaseValue == value,
      orElse: () => throw ArgumentError('Rol no soportado: $value'),
    );
  }
}
