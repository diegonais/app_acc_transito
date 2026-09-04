import 'package:app_acc_transito/services/qr/institutional_qr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = InstitutionalQrService();
  const police = InstitutionalQrPolice(
    nombreCompleto: 'Ana Quispe Rojas',
    grado: 'Sgto.',
    numeroPlaca: 'PL-123',
    unidad: 'Unidad Operativa de Transito',
  );

  test('construye payload institucional con el contenido aprobado', () {
    final payload = service.buildPayload(police).toStructuredText();

    expect(
      payload,
      [
        'FUNCIONARIO POLICIAL',
        'Nombre completo: Ana Quispe Rojas',
        'Grado: Sgto.',
        'Numero de placa: PL-123',
        'Unidad: Unidad Operativa de Transito',
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

  test('genera un QR local no vacio y con matriz legible', () {
    final qr = service.generateForPolice(police);

    expect(qr.moduleCount, greaterThan(0));
    expect(qr.hasDarkModules, isTrue);
    expect(qr.payload.toStructuredText(), contains('Ana Quispe Rojas'));
  });

  test('rechaza payload incompleto', () {
    expect(
      () => service.buildPayload(
        const InstitutionalQrPolice(
          nombreCompleto: ' ',
          grado: 'Sgto.',
          numeroPlaca: 'PL-123',
          unidad: 'Transito',
        ),
      ),
      throwsArgumentError,
    );
  });
}
