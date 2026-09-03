class OfficerManagementException implements Exception {
  const OfficerManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DuplicateUsernameException extends OfficerManagementException {
  const DuplicateUsernameException() : super('El nombre de usuario ya existe.');
}

class DuplicatePlateException extends OfficerManagementException {
  const DuplicatePlateException()
      : super('El numero de placa ya esta registrado.');
}
