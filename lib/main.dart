import 'package:flutter/material.dart';

import 'app.dart';
import 'data/backup/background_backup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeBackgroundBackup();
  } catch (_) {
    // The app must remain fully usable offline even if background scheduling
    // is unavailable on the current platform or not configured yet.
  }

  runApp(const DaynBookApp());
}
