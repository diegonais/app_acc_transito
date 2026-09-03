import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/report_repository.dart';
import 'evidence_photo.dart';

class EvidenceMediaService {
  EvidenceMediaService({
    ImagePicker? picker,
    Directory? temporaryRoot,
    Directory? documentsRoot,
  })  : _picker = picker ?? ImagePicker(),
        _temporaryRoot = temporaryRoot,
        _documentsRoot = documentsRoot;

  final ImagePicker _picker;
  final Directory? _temporaryRoot;
  final Directory? _documentsRoot;

  Future<PhotoInput?> takePhoto({
    EvidencePhotoCategory category = EvidencePhotoCategory.otra,
  }) async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) {
      return null;
    }
    return stagePickedFile(picked, category: category);
  }

  Future<List<PhotoInput>> pickFromGallery({
    EvidencePhotoCategory category = EvidencePhotoCategory.otra,
  }) async {
    final pickedFiles = await _picker.pickMultiImage();
    final staged = <PhotoInput>[];
    for (final picked in pickedFiles) {
      staged.add(await stagePickedFile(picked, category: category));
    }
    return staged;
  }

  Future<PhotoInput> stagePickedFile(
    XFile picked, {
    required EvidencePhotoCategory category,
  }) {
    return stageFile(File(picked.path), category: category);
  }

  Future<PhotoInput> stageFile(
    File source, {
    required EvidencePhotoCategory category,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException(
          'La imagen seleccionada no existe.', source.path);
    }
    final tempDirectory = await _temporaryDirectory();
    final extension = _safeExtension(source.path);
    final fileName = _safeFileName(
      prefix: 'evidencia',
      category: category,
      index: DateTime.now().microsecondsSinceEpoch,
      extension: extension,
    );
    final target = File(p.join(tempDirectory.path, fileName));
    await source.copy(target.path);
    return PhotoInput(
      ruta: target.path,
      tipo: category,
      descripcion: lookupMimeType(target.path),
    );
  }

  Future<List<PhotoInput>> persistPhotosForReport({
    required String numeroCaso,
    required List<PhotoInput> photos,
  }) async {
    final targetDirectory = await reportImagesDirectory(numeroCaso);
    final persisted = <PhotoInput>[];
    for (final (index, photo) in photos.indexed) {
      final source = File(photo.ruta);
      if (!await source.exists()) {
        throw FileSystemException(
          'La fotografia temporal no existe.',
          photo.ruta,
        );
      }
      final extension = _safeExtension(source.path);
      final target = File(
        p.join(
          targetDirectory.path,
          _safeFileName(
            prefix: numeroCaso,
            category: photo.tipo,
            index: index + 1,
            extension: extension,
          ),
        ),
      );
      await source.copy(target.path);
      persisted.add(
        PhotoInput(
          ruta: target.path,
          tipo: photo.tipo,
          descripcion: photo.descripcion,
        ),
      );
      await _deleteIfOwnedTemporary(source);
    }
    return persisted;
  }

  Future<Directory> reportImagesDirectory(String numeroCaso) async {
    final root = await _documentsDirectory();
    final safeCase = _safeSegment(numeroCaso);
    final directory =
        Directory(p.join(root.path, 'reports', safeCase, 'images'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> cleanupTemporaryPhotos(List<PhotoInput> photos) async {
    for (final photo in photos) {
      await _deleteIfOwnedTemporary(File(photo.ruta));
    }
  }

  Future<void> cleanupPersistentPhotos(List<PhotoInput> photos) async {
    for (final photo in photos) {
      final file = File(photo.ruta);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<Directory> _temporaryDirectory() async {
    final root = _temporaryRoot ?? await getTemporaryDirectory();
    final directory = Directory(p.join(root.path, 'reports', 'images'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _documentsDirectory() async {
    final root = _documentsRoot ?? await getApplicationDocumentsDirectory();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<void> _deleteIfOwnedTemporary(File file) async {
    final tempDirectory = await _temporaryDirectory();
    final filePath = p.normalize(file.absolute.path);
    final tempPath = p.normalize(tempDirectory.absolute.path);
    if (p.isWithin(tempPath, filePath) && await file.exists()) {
      await file.delete();
    }
  }

  String _safeFileName({
    required String prefix,
    required EvidencePhotoCategory category,
    required int index,
    required String extension,
  }) {
    final safePrefix = _safeSegment(prefix);
    final safeCategory = category.databaseValue.toLowerCase();
    return '${safePrefix}_${index.toString().padLeft(2, '0')}_$safeCategory'
        '$extension';
  }

  String _safeExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    if (RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)) {
      return extension;
    }
    return '.jpg';
  }

  String _safeSegment(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? 'sin_nombre' : safe;
  }
}
