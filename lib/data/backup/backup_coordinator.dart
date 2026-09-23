import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../local/app_database.dart';
import 'backup_crypto.dart';
import 'google_drive_backup_service.dart';

class BackupCoordinator {
  BackupCoordinator({
    AppDatabase? database,
    BackupCrypto? crypto,
    GoogleDriveBackupService? driveService,
    FlutterSecureStorage? secureStorage,
  })  : _database = database ?? AppDatabase.instance,
        _crypto = crypto ?? BackupCrypto(),
        _drive = driveService ?? GoogleDriveBackupService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _passphraseKey = 'daynbook.backup.passphrase';
  static const _lastSuccessKey = 'daynbook.backup.last_success';
  static const _lastErrorKey = 'daynbook.backup.last_error';

  final AppDatabase _database;
  final BackupCrypto _crypto;
  final GoogleDriveBackupService _drive;
  final FlutterSecureStorage _secureStorage;

  String? get signedInEmail => _drive.signedInEmail;
  bool get hasSignedInAccount => _drive.hasSignedInAccount;

  Future<void> initialize() => _drive.initialize();

  Future<bool> hasStoredPassphrase() async {
    final value = await _secureStorage.read(key: _passphraseKey);
    return value != null && value.trim().length >= 8;
  }

  Future<void> setPassphrase(String passphrase) async {
    if (passphrase.trim().length < 8) {
      throw ArgumentError('Backup passphrase must be at least 8 characters.');
    }
    await _secureStorage.write(key: _passphraseKey, value: passphrase);
  }

  Future<void> clearPassphrase() {
    return _secureStorage.delete(key: _passphraseKey);
  }

  Future<DateTime?> lastSuccessfulBackup() async {
    final value = await _secureStorage.read(key: _lastSuccessKey);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<String?> lastBackupError() {
    return _secureStorage.read(key: _lastErrorKey);
  }

  Future<void> signIn() async {
    await _drive.signIn();
  }

  Future<void> signOut() async {
    await _drive.signOut();
  }

  Future<RemoteBackup> createBackup({
    String? passphrase,
    bool interactive = true,
  }) async {
    final secret = await _resolvePassphrase(passphrase);
    try {
      final snapshot = await _database.exportBackupSnapshot();
      final encrypted = await _crypto.encryptSnapshot(
        snapshot,
        passphrase: secret,
      );
      final envelope = jsonDecode(utf8.decode(encrypted));
      if (envelope is! Map || envelope['payloadSha256'] is! String) {
        throw const FormatException('Encrypted backup metadata is invalid.');
      }

      final backup = await _drive.uploadBackup(
        encrypted,
        schemaVersion: AppDatabase.backupSchemaVersion,
        checksum: envelope['payloadSha256'] as String,
        interactive: interactive,
      );
      await _recordSuccess(backup.modifiedTime.toLocal());
      return backup;
    } catch (error) {
      await _recordError(error);
      rethrow;
    }
  }

  Future<List<RemoteBackup>> listBackups({bool interactive = true}) {
    return _drive.listBackups(interactive: interactive);
  }

  Future<RemoteBackup?> latestBackup({bool interactive = true}) async {
    final backups = await listBackups(interactive: interactive);
    return backups.isEmpty ? null : backups.first;
  }

  Future<void> restoreLatest({
    String? passphrase,
    bool interactive = true,
  }) async {
    final backup = await latestBackup(interactive: interactive);
    if (backup == null) {
      throw StateError('No DaynBook backup was found in Google Drive.');
    }
    await restoreBackup(
      backup,
      passphrase: passphrase,
      interactive: interactive,
    );
  }

  Future<void> restoreBackup(
    RemoteBackup backup, {
    String? passphrase,
    bool interactive = true,
  }) async {
    final secret = await _resolvePassphrase(passphrase);
    try {
      final encrypted = await _drive.downloadBackup(
        backup.id,
        interactive: interactive,
      );
      final snapshot = await _crypto.decryptSnapshot(
        encrypted,
        passphrase: secret,
      );
      await _database.restoreBackupSnapshot(snapshot);
      await _secureStorage.delete(key: _lastErrorKey);
    } catch (error) {
      await _recordError(error);
      rethrow;
    }
  }

  Future<bool> runBackgroundBackup() async {
    if (!await hasStoredPassphrase()) return false;
    try {
      await createBackup(interactive: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _resolvePassphrase(String? provided) async {
    if (provided != null && provided.trim().isNotEmpty) {
      if (provided.trim().length < 8) {
        throw ArgumentError('Backup passphrase must be at least 8 characters.');
      }
      return provided;
    }

    final stored = await _secureStorage.read(key: _passphraseKey);
    if (stored == null || stored.trim().length < 8) {
      throw const BackupPassphraseMissingException();
    }
    return stored;
  }

  Future<void> _recordSuccess(DateTime when) async {
    await _secureStorage.write(
      key: _lastSuccessKey,
      value: when.toUtc().toIso8601String(),
    );
    await _secureStorage.delete(key: _lastErrorKey);
  }

  Future<void> _recordError(Object error) {
    return _secureStorage.write(
      key: _lastErrorKey,
      value: error.toString(),
    );
  }

  Future<void> dispose() => _drive.dispose();
}

class BackupPassphraseMissingException implements Exception {
  const BackupPassphraseMissingException();

  @override
  String toString() => 'Backup passphrase is not configured.';
}
