import 'dart:async';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class RemoteBackup {
  const RemoteBackup({
    required this.id,
    required this.name,
    required this.modifiedTime,
    this.size,
    this.appProperties = const {},
  });

  final String id;
  final String name;
  final DateTime modifiedTime;
  final int? size;
  final Map<String, String?> appProperties;
}

class GoogleDriveBackupService {
  static const _backupPrefix = 'daynbook-backup-';
  static const _backupExtension = '.dnbk';
  static const _maxBackups = 5;
  static const _scopes = <String>[drive.DriveApi.driveAppdataScope];

  final GoogleSignIn _signIn = GoogleSignIn.instance;

  Future<void>? _initialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  GoogleSignInAccount? _account;

  String? get signedInEmail => _account?.email;
  bool get hasSignedInAccount => _account != null;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await _signIn.initialize();
    _authSubscription = _signIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _account = event.user;
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _account = null;
      }
    });

    final lightweight = _signIn.attemptLightweightAuthentication();
    if (lightweight != null) {
      _account = await lightweight;
    }
  }

  Future<GoogleSignInAccount> signIn() async {
    await initialize();
    if (_account != null) return _account!;
    if (!_signIn.supportsAuthenticate()) {
      throw StateError('Interactive Google sign-in is not supported here.');
    }
    _account = await _signIn.authenticate(scopeHint: _scopes);
    return _account!;
  }

  Future<void> signOut() async {
    await initialize();
    await _signIn.signOut();
    _account = null;
  }

  Future<RemoteBackup> uploadBackup(
    Uint8List bytes, {
    required int schemaVersion,
    required String checksum,
    bool interactive = true,
  }) async {
    final client = await _authorizedClient(interactive: interactive);
    try {
      final api = drive.DriveApi(client);
      final now = DateTime.now().toUtc();
      final timestamp = now
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final metadata = drive.File(
        name: '$_backupPrefix$timestamp$_backupExtension',
        parents: const ['appDataFolder'],
        mimeType: 'application/octet-stream',
        appProperties: {
          'app': 'daynbook',
          'formatVersion': '1',
          'schemaVersion': '$schemaVersion',
          'checksum': checksum,
        },
      );
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/octet-stream',
      );

      final created = await api.files.create(
        metadata,
        uploadMedia: media,
        $fields: 'id,name,modifiedTime,size,appProperties',
      );
      final id = created.id;
      if (id == null) {
        throw StateError('Google Drive did not return a backup file id.');
      }

      await _pruneOldBackups(api);
      return _fromDriveFile(created);
    } finally {
      client.close();
    }
  }

  Future<List<RemoteBackup>> listBackups({bool interactive = true}) async {
    final client = await _authorizedClient(interactive: interactive);
    try {
      final api = drive.DriveApi(client);
      final result = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains '$_backupPrefix' and trashed = false",
        orderBy: 'modifiedTime desc',
        pageSize: 20,
        $fields: 'files(id,name,modifiedTime,size,appProperties)',
      );
      return (result.files ?? const <drive.File>[])
          .where((file) => file.id != null && file.name != null)
          .map(_fromDriveFile)
          .toList(growable: false);
    } finally {
      client.close();
    }
  }

  Future<Uint8List> downloadBackup(
    String fileId, {
    bool interactive = true,
  }) async {
    final client = await _authorizedClient(interactive: interactive);
    try {
      final api = drive.DriveApi(client);
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        throw StateError('Google Drive did not return backup media.');
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }

  Future<http.Client> _authorizedClient({required bool interactive}) async {
    await initialize();

    GoogleSignInAccount? account = _account;
    if (account == null && interactive) {
      account = await signIn();
    }
    if (account == null) {
      throw StateError('Google account is not signed in.');
    }

    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
      promptIfNecessary: interactive,
    );
    if (headers == null) {
      throw StateError('Google Drive permission is not available.');
    }

    return _HeaderClient(headers);
  }

  Future<void> _pruneOldBackups(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name contains '$_backupPrefix' and trashed = false",
      orderBy: 'modifiedTime desc',
      pageSize: 20,
      $fields: 'files(id,name,modifiedTime)',
    );
    final files = result.files ?? const <drive.File>[];
    if (files.length <= _maxBackups) return;

    for (final old in files.skip(_maxBackups)) {
      final id = old.id;
      if (id != null) {
        await api.files.delete(id);
      }
    }
  }

  static RemoteBackup _fromDriveFile(drive.File file) {
    final id = file.id;
    final name = file.name;
    if (id == null || name == null) {
      throw const FormatException('Invalid Google Drive backup metadata.');
    }
    return RemoteBackup(
      id: id,
      name: name,
      modifiedTime: file.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0),
      size: int.tryParse(file.size ?? ''),
      appProperties: file.appProperties ?? const {},
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
  }
}

class _HeaderClient extends http.BaseClient {
  _HeaderClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    for (final entry in _headers.entries) {
      request.headers.putIfAbsent(entry.key, () => entry.value);
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
