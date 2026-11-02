import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'remote_gateway.dart';

class PendingOnlineFile {
  PendingOnlineFile(
      {required this.localPath, required this.kind, this.type, this.reportId})
      : reservation = const Uuid().v4();
  final String reservation;
  final String localPath;
  final String kind;
  final String? type;
  final int? reportId;
  String? digest;
  String? mime;
  Map<String, dynamic>? descriptor;
  bool uploadAttempted = false;
  bool reservationAttempted = false;
  bool verificationAttempted = false;
}

/// Un servicio por cliente; toda operación de archivos se serializa.
class OnlineFileService {
  OnlineFileService(this.gateway,
      {Future<Directory> Function()? cacheDirectory})
      : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;
  final RemoteGateway gateway;
  final Future<Directory> Function() _cacheDirectory;
  final String _cacheId = const Uuid().v4();
  Future<void> _tail = Future.value();

  Future<T> serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _checkActor(String uid) {
    if (gateway.userId != uid)
      throw const OnlineException(
          'Cambió la sesión durante la operación de archivos.');
  }

  Future<void> prepare(
          String uid, String operation, List<PendingOnlineFile> files) =>
      serialized(() async {
        for (final file in files) {
          _checkActor(uid);
          final source = File(file.localPath);
          final size = await source.length();
          final limit = file.kind == 'PDF' ? 10485760 : 5242880;
          if (size == 0 || size > limit)
            throw const OnlineException(
                'Archivo vacío o demasiado grande: máximo 5 MiB por imagen y 10 MiB por PDF.');
          final bytes = await source.readAsBytes();
          final mime = detectMime(bytes);
          if ((file.kind == 'PDF' && mime != 'application/pdf') ||
              (file.kind == 'CROQUIS' && mime != 'image/png') ||
              (file.kind == 'FOTOGRAFIA' &&
                  !const ['image/png', 'image/jpeg'].contains(mime))) {
            throw const OnlineException(
                'Tipo de archivo no admitido. Use JPEG/PNG; el croquis requiere PNG y el documento PDF.');
          }
          final hash = await digest(bytes);
          if (file.digest != null && file.digest != hash)
            throw const OnlineException(
                'El archivo cambió. No se reutilizará su reserva con otros bytes.');
          file.digest = hash;
          file.mime = mime;
          _checkActor(uid);
          file.reservationAttempted = true;
          file.descriptor ??=
              Map<String, dynamic>.from(await gateway.rpc('reservar_archivo', {
            'p_reserva': file.reservation,
            'p_operacion': operation,
            'p_clase': file.kind,
            'p_tipo': file.type,
            'p_mime': mime,
            'p_bytes': size,
            'p_sha256': hash,
            'p_informe': file.reportId,
          }) as Map);
          final r = file.descriptor!;
          if (r['auth_uid'] != uid ||
              r['operation_id'] != operation ||
              r['reserva_id'] != file.reservation ||
              r['objeto'] != '$uid/$operation/${file.reservation}') {
            throw const OnlineException(
                'La reserva recibida no corresponde a la operación.');
          }
          if (!file.uploadAttempted) {
            file.uploadAttempted = true;
            _checkActor(uid);
            await gateway.upload(r['bucket_id'], r['objeto'], bytes, mime!);
          } else {
            // Una carga con respuesta perdida jamás se sobrescribe ni se duplica.
            _checkActor(uid);
            final existing =
                await gateway.download(r['bucket_id'], r['objeto']);
            if (await digest(existing) != hash)
              throw const OnlineException(
                  'No se confirmó el contenido de la carga anterior.');
          }
          _checkActor(uid);
          if (!file.verificationAttempted) {
            file.verificationAttempted = true;
            // Una vez por reserva. Ningún error, incluido 546, provoca replay.
            await gateway.verify(file.reservation);
          }
          _checkActor(uid);
          final status = await gateway.select('reservas_archivos',
              equals: {'reserva_id': file.reservation});
          if (status.length != 1 ||
              !const ['VERIFICADO', 'VINCULADO']
                  .contains(status.single['estado'])) {
            throw const OnlineException(
                'Archivo no confirmado por el verificador. No se repetirá la verificación. Requiere revisión; conserve el formulario.');
          }
        }
      });

  Future<String> readFile(String uid, Map<String, dynamic> descriptor) =>
      serialized(() async {
        _checkActor(uid);
        final bucket = descriptor['bucket_id'] as String;
        if (!const ['transito-evidencias', 'transito-pdf'].contains(bucket))
          throw const OnlineException('Bucket de archivo no reconocido.');
        final bytes = await gateway.download(bucket, descriptor['objeto']);
        _checkActor(uid);
        if (bytes.length > (bucket == 'transito-pdf' ? 10485760 : 5242880))
          throw const OnlineException('El archivo excede el límite técnico.');
        final mime = detectMime(bytes);
        if (mime == null)
          throw const OnlineException('Formato de archivo no reconocido.');
        final folder = Directory(path.join(
            (await _cacheDirectory()).path, 'transito_online', _cacheId, uid));
        await folder.create(recursive: true);
        final extension = mime == 'image/png'
            ? 'png'
            : mime == 'image/jpeg'
                ? 'jpg'
                : 'pdf';
        final file = File(
            path.join(folder.path, '${descriptor['id_archivo']}.$extension'));
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      });

  static Future<String> digest(List<int> bytes) async =>
      (await Sha256().hash(bytes))
          .bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  static String? detectMime(Uint8List b) {
    if (b.length >= 8 &&
        Iterable<int>.generate(8)
            .every((i) => b[i] == const [137, 80, 78, 71, 13, 10, 26, 10][i]))
      return 'image/png';
    if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255)
      return 'image/jpeg';
    if (b.length >= 5 && String.fromCharCodes(b.take(5)) == '%PDF-')
      return 'application/pdf';
    return null;
  }
}
