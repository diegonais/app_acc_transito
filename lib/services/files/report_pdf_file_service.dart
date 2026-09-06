import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ReportPdfFileService {
  const ReportPdfFileService({Directory? documentsRoot})
      : _documentsRoot = documentsRoot;

  final Directory? _documentsRoot;

  Future<String> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final root = _documentsRoot ?? await getApplicationDocumentsDirectory();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    final safeName = _safeFileName(fileName);
    final caseSegment = _caseSegment(safeName);
    final directory =
        Directory(p.join(root.path, 'reports', caseSegment, 'pdf'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File(p.join(directory.path, safeName));
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    return file.path;
  }

  String _caseSegment(String fileName) {
    final stem = p.basenameWithoutExtension(fileName);
    final firstPart = stem.split('_').first;
    final safe = firstPart.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? 'sin_caso' : safe;
  }

  String _safeFileName(String fileName) {
    final stem = p.basenameWithoutExtension(fileName);
    final safeStem =
        stem.replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_-]'), '_');
    return '${safeStem.isEmpty ? 'informe_accion_directa' : safeStem}.pdf';
  }
}
