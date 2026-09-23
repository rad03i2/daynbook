import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/backup/application/backup_controller.dart';
import 'features/home/presentation/main_shell.dart';
import 'features/ledger/application/ledger_controller.dart';

class DaynBookApp extends StatefulWidget {
  const DaynBookApp({super.key});

  @override
  State<DaynBookApp> createState() => _DaynBookAppState();
}

class _DaynBookAppState extends State<DaynBookApp> {
  late final LedgerController _ledgerController;
  late final BackupController _backupController;

  @override
  void initState() {
    super.initState();
    _ledgerController = LedgerController()..initialize();
    _backupController = BackupController(
      onRestored: () async {
        _ledgerController.clearSelection();
        await _ledgerController.loadCustomers(search: '');
      },
    )..initialize();
  }

  @override
  void dispose() {
    _backupController.dispose();
    _ledgerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دفتر الدين',
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: MainShell(
        ledgerController: _ledgerController,
        backupController: _backupController,
      ),
    );
  }
}
