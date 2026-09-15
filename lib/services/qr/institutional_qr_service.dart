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

class InstitutionalQrReport {
  const InstitutionalQrReport({
    required this.numeroCaso,
    required this.fechaRegistro,
  });

  final String numeroCaso;
  final DateTime fechaRegistro;

  String toStructuredText() {
    final date = fechaRegistro;
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp = '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}'
        '${date.isUtc ? ' UTC' : ''}';
    return 'INFORME DE ACCIÓN DIRECTA\n'
        'Número de caso / correlativo: $numeroCaso\n'
        'Fecha y hora de registro definitivo: $timestamp';
  }
}

class InstitutionalQrPayload {
  const InstitutionalQrPayload({
    required this.nombreCompleto,
    required this.grado,
    required this.numeroPlaca,
    required this.unidad,
    this.report,
  });

  final String nombreCompleto;
  final String grado;
  final String numeroPlaca;
  final String unidad;
  final InstitutionalQrReport? report;

  String toStructuredText() {
    return [
      if (report != null) report!.toStructuredText(),
      'FUNCIONARIO POLICIAL',
      'Nombre completo: $nombreCompleto',
      'Grado: $grado',
      'Número de placa: $numeroPlaca',
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

  InstitutionalQrPayload buildPayload(InstitutionalQrPolice police,
      {InstitutionalQrReport? report}) {
    return InstitutionalQrPayload(
      nombreCompleto: _requiredText(
        police.nombreCompleto,
        'nombre completo',
      ),
      grado: _requiredText(police.grado, 'grado'),
      numeroPlaca: _requiredText(police.numeroPlaca, 'número de placa'),
      unidad: _requiredText(police.unidad, 'unidad'),
      report: report == null
          ? null
          : InstitutionalQrReport(
              numeroCaso: _requiredText(report.numeroCaso, 'número de caso'),
              fechaRegistro: report.fechaRegistro,
            ),
    );
  }

  InstitutionalQrCode generateForPolice(InstitutionalQrPolice police) {
    return _generate(buildPayload(police));
  }

  InstitutionalQrCode generateForReport({
    required InstitutionalQrPolice police,
    required InstitutionalQrReport report,
  }) {
    return _generate(buildPayload(police, report: report));
  }

  InstitutionalQrCode _generate(InstitutionalQrPayload payload) {
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
      throw ArgumentError.value(value, fieldName, 'No puede estar vacío.');
    }
    return trimmed;
  }
}
