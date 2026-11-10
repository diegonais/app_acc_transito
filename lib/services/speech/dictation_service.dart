import 'package:flutter/services.dart';

/// Reconocimiento exclusivamente en el dispositivo; no conserva audio.
class DictationService {
  const DictationService();
  static const _channel = MethodChannel('app_acc_transito/dictation');

  Future<String?> listen() => _channel.invokeMethod<String>('listen');
  Future<void> stop() => _channel.invokeMethod<void>('stop');
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
