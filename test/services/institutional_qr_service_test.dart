import 'package:app_acc_transito/services/qr/institutional_qr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = InstitutionalQrService();
  const police = InstitutionalQrPolice(
    nombreCompleto: 'Ana Quispe Rojas',
    grado: 'Sgto.',
    numeroPlaca: 'PL-123',
    unidad: 'Unidad Operativa de Tránsito',
  );

  test('construye payload institucional con el contenido aprobado', () {
    final payload = service.buildPayload(police).toStructuredText();

    expect(
      payload,
      [
        'FUNCIONARIO POLICIAL',
        'Nombre completo: Ana Quispe Rojas',
        'Grado: Sgto.',
        'Número de placa: PL-123',
        'Unidad: Unidad Operativa de Tránsito',
      ].join('\n'),
    );
  });

  test('excluye datos no aprobados del payload', () {
    final payload = service.buildPayload(police).toStructuredText();

    expect(payload, isNot(contains('1234567')));
    expect(payload.toLowerCase(), isNot(contains('c.i.')));
    expect(payload.toLowerCase(), isNot(contains('cedula')));
    expect(payload.toLowerCase(), isNot(contains('usuario')));
    expect(payload.toLowerCase(), isNot(contains('contrasena')));
    expect(payload.toLowerCase(), isNot(contains('hash')));
    expect(payload.toLowerCase(), isNot(contains('id_')));
    expect(payload.toLowerCase(), isNot(contains('dispositivo')));
  });

  test('genera un QR local no vacío y con matriz legible', () {
    final qr = service.generateForPolice(police);

    expect(qr.moduleCount, greaterThan(0));
    expect(qr.hasDarkModules, isTrue);
    expect(qr.payload.toStructuredText(), contains('Ana Quispe Rojas'));
  });

  test('QR de informe incluye caso y registro definitivo con segundos', () {
    final report = InstitutionalQrReport(
        numeroCaso: '2026-000042',
        fechaRegistro: DateTime(2026, 9, 14, 21, 7, 9));
    final code = service.generateForReport(police: police, report: report);
    expect(
        code.payload.toStructuredText(),
        'INFORME DE ACCIÓN DIRECTA\n'
        'Número de caso / correlativo: 2026-000042\n'
        'Fecha y hora de registro definitivo: 14/09/2026 21:07:09\n'
        '${service.buildPayload(police).toStructuredText()}');
    expect(code.hasDarkModules, isTrue);
    expect(
        service
            .generateForReport(police: police, report: report)
            .payload
            .toStructuredText(),
        code.payload.toStructuredText());
  });

  test('QR identifica fechas UTC y rechaza un número de caso vacío', () {
    final timestamp = DateTime.utc(2026, 9, 14, 21, 7, 9);
    expect(
        service
            .generateForReport(
                police: police,
                report: InstitutionalQrReport(
                    numeroCaso: '2026-000042', fechaRegistro: timestamp))
            .payload
            .toStructuredText(),
        contains('14/09/2026 21:07:09 UTC'));
    expect(
        () => service.generateForReport(
            police: police,
            report: InstitutionalQrReport(
                numeroCaso: ' ', fechaRegistro: timestamp)),
        throwsArgumentError);
  });

  test('rechaza payload incompleto', () {
    expect(
      () => service.buildPayload(
        const InstitutionalQrPolice(
          nombreCompleto: ' ',
          grado: 'Sgto.',
          numeroPlaca: 'PL-123',
          unidad: 'Tránsito',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('conserva ñ y tildes en el QR institucional', () {
    final code = service.generateForPolice(const InstitutionalQrPolice(
        nombreCompleto: 'José Muñoz Peña',
        grado: 'Sgto.',
        numeroPlaca: 'PL-Ñ01',
        unidad: 'División de Tránsito'));
    expect(code.payload.toStructuredText(),
        contains('Nombre completo: José Muñoz Peña'));
    expect(code.payload.toStructuredText(),
        contains('Unidad: División de Tránsito'));
    expect(code.hasDarkModules, isTrue);
  });
}
