import 'dart:io';

import 'package:app_acc_transito/data/repositories/report_repository.dart';
import 'package:app_acc_transito/services/media/evidence_media_service.dart';
import 'package:app_acc_transito/services/media/evidence_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;
  late Directory temporaryRoot;
  late Directory documentsRoot;
  late EvidenceMediaService service;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('evidence_media_test_');
    temporaryRoot = Directory(p.join(sandbox.path, 'tmp'));
    documentsRoot = Directory(p.join(sandbox.path, 'docs'));
    service = EvidenceMediaService(
      temporaryRoot: temporaryRoot,
      documentsRoot: documentsRoot,
    );
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('copia imagen seleccionada al area temporal propia', () async {
    final source = File(p.join(sandbox.path, 'origen con espacios.JPG'));
    await source.writeAsBytes([1, 2, 3, 4]);

    final staged = await service.stageFile(
      source,
      category: EvidencePhotoCategory.licencia,
    );

    expect(staged.tipo, EvidencePhotoCategory.licencia);
    expect(staged.ruta, contains(p.join('reports', 'images')));
    expect(staged.ruta, endsWith('.jpg'));
    expect(await File(staged.ruta).exists(), isTrue);
    expect(await source.exists(), isTrue);
  });

  test(
      'persiste evidencias bajo reports numero caso images y limpia temporales',
      () async {
    final firstSource = File(p.join(sandbox.path, 'foto-1.jpg'));
    final secondSource = File(p.join(sandbox.path, 'foto-2.png'));
    await firstSource.writeAsBytes([1, 2, 3]);
    await secondSource.writeAsBytes([4, 5, 6]);
    final staged = [
      await service.stageFile(
        firstSource,
        category: EvidencePhotoCategory.panoramica,
      ),
      await service.stageFile(
        secondSource,
        category: EvidencePhotoCategory.placa,
      ),
    ];
    final temporaryPaths = staged.map((photo) => photo.ruta).toList();

    final persisted = await service.persistPhotosForReport(
      numeroCaso: '2026-000001',
      photos: staged,
    );

    expect(persisted, hasLength(2));
    expect(
      persisted.first.ruta,
      contains(p.join('reports', '2026-000001', 'images')),
    );
    expect(persisted.first.ruta, endsWith('_panoramica.jpg'));
    expect(persisted.last.ruta, endsWith('_placa.png'));
    expect(await File(persisted.first.ruta).exists(), isTrue);
    expect(await File(persisted.last.ruta).exists(), isTrue);
    for (final path in temporaryPaths) {
      expect(await File(path).exists(), isFalse);
    }
  });

  test('limpia temporales al cancelar y falla si falta el archivo', () async {
    final source = File(p.join(sandbox.path, 'foto.jpg'));
    await source.writeAsBytes([1, 2, 3]);
    final staged = await service.stageFile(
      source,
      category: EvidencePhotoCategory.otra,
    );

    await service.cleanupTemporaryPhotos([staged]);

    expect(await File(staged.ruta).exists(), isFalse);
    await expectLater(
      service.persistPhotosForReport(numeroCaso: '2026-000002', photos: [
        const PhotoInput(
          ruta: 'C:/no/existe/foto.jpg',
          tipo: EvidencePhotoCategory.otra,
        ),
      ]),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('limpia fotos persistentes cuando una transaccion debe revertirse',
      () async {
    final source = File(p.join(sandbox.path, 'foto-rollback.jpg'));
    await source.writeAsBytes([7, 8, 9]);
    final staged = await service.stageFile(
      source,
      category: EvidencePhotoCategory.otra,
    );
    final persisted = await service.persistPhotosForReport(
      numeroCaso: '2026-000099',
      photos: [staged],
    );

    expect(await File(persisted.single.ruta).exists(), isTrue);

    await service.cleanupPersistentPhotos(persisted);

    expect(await File(persisted.single.ruta).exists(), isFalse);
  });
}
