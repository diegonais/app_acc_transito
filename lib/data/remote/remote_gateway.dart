import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Única frontera de red, sustituible por dobles sin cuentas ni endpoints reales.
abstract interface class RemoteGateway {
  String? get userId;
  Stream<bool> get sessionChanges;
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<List<Map<String, dynamic>>> select(String table,
      {Map<String, Object> equals = const {}});
  Future<dynamic> rpc(String name, Map<String, dynamic> parameters);
  Future<void> upload(
      String bucket, String object, Uint8List bytes, String mime);
  Future<Uint8List> download(String bucket, String object);
  Future<void> verify(String reservation);
}

class OnlineException implements Exception {
  const OnlineException(this.message);
  final String message;
  @override
  String toString() => message;
}

bool isTransientOnlineError(Object error) =>
    error is TimeoutException ||
    error is SocketException ||
    error is http.ClientException ||
    (error is PostgrestException &&
        const ['40001', '40P01', '502', '503', '504'].contains(error.code));

class SupabaseGateway implements RemoteGateway {
  SupabaseGateway(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Stream<bool> get sessionChanges =>
      client.auth.onAuthStateChange.map((event) => event.session != null);
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
  @override
  Future<List<Map<String, dynamic>>> select(String table,
      {Map<String, Object> equals = const {}}) async {
    // Paginación: no truncar silenciosamente el listado al límite PostgREST.
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 500) {
      var query = client.from(table).select();
      for (final entry in equals.entries) {
        query = query.eq(entry.key, entry.value);
      }
      const ids = {
        'usuarios': 'id_usuario',
        'policias': 'id_policia',
        'informes': 'id_informe',
        'conductores': 'id_conductor',
        'vehiculos': 'id_vehiculo',
        'personas_involucradas': 'id_persona',
        'archivos_informe': 'id_archivo',
        'fotografias': 'id_fotografia',
        'reservas_archivos': 'reserva_id'
      };
      final page = await query
          .order(ids[table]!)
          .range(offset, offset + 499)
          .retry(enabled: false)
          .timeout(const Duration(seconds: 25));
      rows.addAll(page);
      if (page.length < 500) return rows;
    }
  }

  @override
  Future<dynamic> rpc(String name, Map<String, dynamic> parameters) => client
      .rpc(name, params: parameters)
      .retry(enabled: false)
      .timeout(const Duration(seconds: 30));
  @override
  Future<void> upload(
      String bucket, String object, Uint8List bytes, String mime) async {
    await client.storage.from(bucket).uploadBinary(object, bytes,
        retryAttempts: 0,
        fileOptions: FileOptions(contentType: mime, upsert: false));
  }

  @override
  Future<Uint8List> download(String bucket, String object) =>
      client.storage.from(bucket).download(object);
  @override
  Future<void> verify(String reservation) async {
    try {
      final response = await client.functions
          .invoke('verificar-archivo', body: {'reserva_id': reservation});
      if (response.status != 200) {
        throw const OnlineException(
            'Verificación de archivo no confirmada. No se repetirá automáticamente.');
      }
    } on FunctionException catch (error) {
      if (error.status == 546) {
        throw const OnlineException(
            'El verificador respondió HTTP 546. El riesgo de recursos sigue abierto. No se repetirá esta verificación.');
      }
      throw const OnlineException(
          'No se confirmó la verificación del archivo. No se repetirá automáticamente; conserve el formulario.');
    }
  }
}
