import 'dart:developer' as developer;

import '../data/repositories/report_repository.dart';
import '../features/auth/domain/auth_exceptions.dart';
import '../features/officers/domain/officer_management_exceptions.dart';

String userMessage(Object error, {required String fallback}) {
  if (error is AuthException) return error.message;
  if (error is OfficerManagementException) return error.message;
  if (error is ReportValidationException) return error.messages.join('\n');
  // No registrar valores del formulario, credenciales ni rutas privadas.
  developer.log('$fallback (${error.runtimeType})', name: 'acc_transito');
  return fallback;
}
