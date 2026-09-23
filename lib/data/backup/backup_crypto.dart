import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupCrypto {
  static const int formatVersion = 1;
  static const int _kdfIterations = 310000;
  static const int _saltLength = 16;

  final AesGcm _cipher = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();
  final Pbkdf2 _kdf = Pbkdf2.hmacSha256(
    iterations: _kdfIterations,
    bits: 256,
  );

  Future<Uint8List> encryptSnapshot(
    Map<String, dynamic> snapshot, {
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);

    final clearJson = utf8.encode(jsonEncode(snapshot));
    final checksum = await _sha256.hash(clearJson);
    final compressed = gzip.encode(clearJson);
    final salt = _randomBytes(_saltLength);
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final box = await _cipher.encrypt(
      compressed,
      secretKey: secretKey,
    );

    final envelope = <String, dynamic>{
      'format': 'daynbook-backup',
      'formatVersion': formatVersion,
      'schemaVersion': snapshot['schemaVersion'],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'compression': 'gzip',
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'kdfIterations': _kdfIterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
      'payloadSha256': base64Encode(checksum.bytes),
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  Future<Map<String, dynamic>> decryptSnapshot(
    List<int> encryptedBytes, {
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);

    final decoded = jsonDecode(utf8.decode(encryptedBytes));
    if (decoded is! Map) {
      throw const FormatException('Invalid backup envelope');
    }
    final envelope = Map<String, dynamic>.from(decoded);

    if (envelope['format'] != 'daynbook-backup' ||
        envelope['formatVersion'] != formatVersion) {
      throw const FormatException('Unsupported backup format');
    }

    final iterations = envelope['kdfIterations'];
    if (iterations is! int || iterations < 100000) {
      throw const FormatException('Invalid KDF parameters');
    }

    try {
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final cipherText = base64Decode(envelope['cipherText'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      final expectedChecksum = envelope['payloadSha256'] as String;

      final kdf = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
      final secretKey = await kdf.deriveKeyFromPassword(
        password: passphrase,
        nonce: salt,
      );
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
      final compressed = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      final clearJson = gzip.decode(compressed);
      final actualChecksum = await _sha256.hash(clearJson);

      if (base64Encode(actualChecksum.bytes) != expectedChecksum) {
        throw const FormatException('Backup checksum mismatch');
      }

      final snapshot = jsonDecode(utf8.decode(clearJson));
      if (snapshot is! Map) {
        throw const FormatException('Invalid backup payload');
      }
      return Map<String, dynamic>.from(snapshot);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Unable to decrypt backup. Check the backup passphrase.',
      );
    }
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < 8) {
      throw ArgumentError.value(
        passphrase,
        'passphrase',
        'Backup passphrase must contain at least 8 characters',
      );
    }
  }
}
