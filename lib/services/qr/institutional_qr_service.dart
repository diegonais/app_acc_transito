import 'package:qr/qr.dart';

class InstitutionalQrPolice {
  const InstitutionalQrPolice({
    required this.nombreCompleto,
    required this.grado,
    required this.numeroPlaca,
    required this.unidad,
  });

  final String nombreCompleto;
  final String grado;
  final String numeroPlaca;
  final String unidad;
}

class InstitutionalQrPayload {
  const InstitutionalQrPayload({
    required this.nombreCompleto,
    required this.grado,
    required this.numeroPlaca,
    required this.unidad,
  });

  final String nombreCompleto;
  final String grado;
  final String numeroPlaca;
  final String unidad;

  String toStructuredText() {
    return [
      'FUNCIONARIO POLICIAL',
      'Nombre completo: $nombreCompleto',
      'Grado: $grado',
      'Numero de placa: $numeroPlaca',
      'Unidad: $unidad',
    ].join('\n');
  }
}

class InstitutionalQrCode {
  const InstitutionalQrCode({
    required this.payload,
    required this.image,
  });

  final InstitutionalQrPayload payload;
  final QrImage image;

  int get moduleCount => image.moduleCount;

  bool get hasDarkModules {
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          return true;
        }
      }
    }
    return false;
  }
}

class InstitutionalQrService {
  const InstitutionalQrService();

  InstitutionalQrPayload buildPayload(InstitutionalQrPolice police) {
    return InstitutionalQrPayload(
      nombreCompleto: _requiredText(
        police.nombreCompleto,
        'nombre completo',
      ),
      grado: _requiredText(police.grado, 'grado'),
      numeroPlaca: _requiredText(police.numeroPlaca, 'numero de placa'),
      unidad: _requiredText(police.unidad, 'unidad'),
    );
  }

  InstitutionalQrCode generateForPolice(InstitutionalQrPolice police) {
    final payload = buildPayload(police);
    final code = QrCode.fromData(
      data: payload.toStructuredText(),
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    return InstitutionalQrCode(
      payload: payload,
      image: QrImage(code),
    );
  }

  static String _requiredText(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, fieldName, 'No puede estar vacio.');
    }
    return trimmed;
  }
}
