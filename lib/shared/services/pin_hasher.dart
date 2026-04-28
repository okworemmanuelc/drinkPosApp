import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 helper for hashing user PINs.
///
/// `package:crypto` ships HMAC-SHA256 but no PBKDF2; the outer iteration loop
/// is implemented here. Output and salt are base64-encoded for storage.
class PinHasher {
  PinHasher._();

  static const int defaultIterations = 100000;
  static const int _saltBytes = 16;
  static const int _derivedKeyBytes = 32;

  static final Random _random = Random.secure();

  static String generateSaltBase64() {
    final salt = Uint8List(_saltBytes);
    for (var i = 0; i < _saltBytes; i++) {
      salt[i] = _random.nextInt(256);
    }
    return base64.encode(salt);
  }

  /// PBKDF2-HMAC-SHA256(pin, salt, iterations) → 32-byte derived key, base64.
  static String hashBase64(String pin, String saltB64, int iterations) {
    if (iterations < 1) {
      throw ArgumentError.value(iterations, 'iterations', 'must be >= 1');
    }
    final salt = base64.decode(saltB64);
    final pinBytes = utf8.encode(pin);
    final hmac = Hmac(sha256, pinBytes);

    const blockSize = 32; // SHA-256 output size
    const blockCount = (_derivedKeyBytes + blockSize - 1) ~/ blockSize;
    final out = Uint8List(blockCount * blockSize);

    for (var block = 1; block <= blockCount; block++) {
      final firstInput = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;

      var u = Uint8List.fromList(hmac.convert(firstInput).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < blockSize; j++) {
          t[j] ^= u[j];
        }
      }

      out.setRange((block - 1) * blockSize, block * blockSize, t);
    }

    return base64.encode(out.sublist(0, _derivedKeyBytes));
  }

  /// XOR-accumulating compare. Length-mismatch returns false but still walks
  /// the shorter input to keep timing roughly constant for equal-length probes.
  static bool constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    final len = aBytes.length < bBytes.length ? aBytes.length : bBytes.length;
    var diff = aBytes.length ^ bBytes.length;
    for (var i = 0; i < len; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }
}
