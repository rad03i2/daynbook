import 'package:flutter/foundation.dart';

import '../../../data/backup/backup_coordinator.dart';
import '../../../data/backup/google_drive_backup_service.dart';

class BackupController extends ChangeNotifier {
  BackupController({
    BackupCoordinator? coordinator,
    Future<void> Function()? onRestored,
  })  : _coordinator = coordinator ?? BackupCoordinator(),
        _onRestored = onRestored;

  final BackupCoordinator _coordinator;
  final Future<void> Function()? _onRestored;

  bool _isBusy = false;
  bool _hasPassphrase = false;
  String? _email;
  DateTime? _lastSuccessfulBackup;
  String? _lastError;
  List<RemoteBackup> _remoteBackups = const [];

  bool get isBusy => _isBusy;
  bool get hasPassphrase => _hasPassphrase;
  String? get email => _email;
  DateTime? get lastSuccessfulBackup => _lastSuccessfulBackup;
  String? get lastError => _lastError;
  List<RemoteBackup> get remoteBackups => _remoteBackups;
  bool get isGoogleConnected => _email != null;

  Future<void> initialize() async {
    await _run(() async {
      await _coordinator.initialize();
      await _refreshLocalState();
    });
  }

  Future<void> signIn() async {
    await _run(() async {
      await _coordinator.signIn();
      await _refreshLocalState();
      await _loadRemoteBackupsInternal();
    });
  }

  Future<void> signOut() async {
    await _run(() async {
      await _coordinator.signOut();
      _email = null;
      _remoteBackups = const [];
    });
  }

  Future<void> setPassphrase(String value) async {
    await _run(() async {
      await _coordinator.setPassphrase(value);
      _hasPassphrase = true;
    });
  }

  Future<void> clearPassphrase() async {
    await _run(() async {
      await _coordinator.clearPassphrase();
      _hasPassphrase = false;
    });
  }

  Future<void> backupNow({String? passphrase}) async {
    await _run(() async {
      if (passphrase != null && passphrase.trim().isNotEmpty) {
        await _coordinator.setPassphrase(passphrase);
        _hasPassphrase = true;
      }
      await _coordinator.createBackup(passphrase: passphrase);
      await _refreshLocalState();
      await _loadRemoteBackupsInternal();
    });
  }

  Future<void> loadRemoteBackups() async {
    await _run(_loadRemoteBackupsInternal);
  }

  Future<void> restore(
    RemoteBackup backup, {
    String? passphrase,
  }) async {
    await _run(() async {
      await _coordinator.restoreBackup(
        backup,
        passphrase: passphrase,
      );
      if (_onRestored != null) {
        await _onRestored!();
      }
      await _refreshLocalState();
    });
  }

  Future<void> restoreLatest({String? passphrase}) async {
    await _run(() async {
      await _coordinator.restoreLatest(passphrase: passphrase);
      if (_onRestored != null) {
        await _onRestored!();
      }
      await _refreshLocalState();
      await _loadRemoteBackupsInternal();
    });
  }

  Future<void> _loadRemoteBackupsInternal() async {
    _remoteBackups = await _coordinator.listBackups();
    _email = _coordinator.signedInEmail;
  }

  Future<void> _refreshLocalState() async {
    _hasPassphrase = await _coordinator.hasStoredPassphrase();
    _lastSuccessfulBackup = await _coordinator.lastSuccessfulBackup();
    _lastError = await _coordinator.lastBackupError();
    _email = _coordinator.signedInEmail;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    _lastError = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _lastError = _friendlyError(error);
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    if (error is BackupPassphraseMissingException) {
      return 'عيّن عبارة حماية للنسخ الاحتياطي أولاً.';
    }
    if (text.contains('Google account is not signed in')) {
      return 'سجّل الدخول إلى حساب Google أولاً.';
    }
    if (text.contains('permission is not available')) {
      return 'يلزم منح التطبيق صلاحية النسخ الاحتياطي في Google Drive.';
    }
    if (text.contains('Unable to decrypt')) {
      return 'عبارة الحماية غير صحيحة أو النسخة تالفة.';
    }
    if (text.contains('No DaynBook backup')) {
      return 'لا توجد نسخة DaynBook محفوظة في Google Drive.';
    }
    return 'تعذر إكمال عملية النسخ الاحتياطي. حاول مرة أخرى.';
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }
}
