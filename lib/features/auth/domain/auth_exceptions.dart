class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException()
      : super('Usuario o contraseña incorrectos.');
}

class InactiveUserException extends AuthException {
  const InactiveUserException() : super('El usuario está inactivo.');
}

class MissingPoliceProfileException extends AuthException {
  const MissingPoliceProfileException()
      : super('El usuario policía no tiene datos de policía activos.');
}

class AuthorizationException extends AuthException {
  const AuthorizationException(super.message);
}
