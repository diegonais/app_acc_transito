class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException()
      : super('Usuario o contrasena incorrectos.');
}

class InactiveUserException extends AuthException {
  const InactiveUserException() : super('El usuario esta inactivo.');
}

class MissingPoliceProfileException extends AuthException {
  const MissingPoliceProfileException()
      : super('El usuario policia no tiene datos de policia activos.');
}

class AuthorizationException extends AuthException {
  const AuthorizationException(super.message);
}
