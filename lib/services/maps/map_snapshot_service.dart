import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MapSnapshotService {
  const MapSnapshotService();

  Future<void> cleanupGeneratedSketches(Iterable<String> paths) async {
    if (paths.isEmpty) return;
    final root = await getApplicationDocumentsDirectory();
    final ownedDirectory = p.normalize(p.join(root.path, 'croquis'));
    for (final path in paths) {
      final file = File(path);
      if (p.isWithin(ownedDirectory, p.normalize(file.absolute.path)) &&
          await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String?> saveBoundaryAsPng(
    RenderRepaintBoundary? boundary, {
    required String fileNamePrefix,
    double pixelRatio = 2,
  }) async {
    if (boundary == null || boundary.debugNeedsPaint) {
      return null;
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? data;
    try {
      data = await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
    if (data == null) {
      return null;
    }

    final directory = await getApplicationDocumentsDirectory();
    final sketchesDirectory = Directory(p.join(directory.path, 'croquis'));
    if (!await sketchesDirectory.exists()) {
      await sketchesDirectory.create(recursive: true);
    }

    final safePrefix =
        fileNamePrefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      p.join(
        sketchesDirectory.path,
        '${safePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }
}
