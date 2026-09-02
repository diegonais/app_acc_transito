import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class PasswordHasher {
  PasswordHasher({
    Pbkdf2? algorithm,
    Random? random,
    this.saltLength = 16,
  })  : _algorithm = algorithm ??
            Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: 210000,
              bits: 256,
            ),
        _random = random ?? Random.secure();

  static const String _prefix = 'pbkdf2_sha256';

  final Pbkdf2 _algorithm;
  final Random _random;
  final int saltLength;

  Future<String> hash(String password) async {
    final salt = List<int>.generate(saltLength, (_) => _random.nextInt(256));
    final secretKey = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final hashBytes = await secretKey.extractBytes();
    return [
      _prefix,
      _algorithm.iterations.toString(),
      base64Encode(salt),
      base64Encode(hashBytes),
    ].join(r'$');
  }

  Future<bool> verify({
    required String password,
    required String encodedHash,
  }) async {
    try {
      final parts = encodedHash.split(r'$');
      if (parts.length != 4 || parts[0] != _prefix) {
        return false;
      }

      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1) {
        return false;
      }

      final salt = base64Decode(parts[2]);
      final expectedHash = base64Decode(parts[3]);
      final algorithm = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: expectedHash.length * 8,
      );
      final secretKey = await algorithm.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      final actualHash = await secretKey.extractBytes();
      return _constantTimeEquals(actualHash, expectedHash);
    } on FormatException {
      return false;
    }
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}
