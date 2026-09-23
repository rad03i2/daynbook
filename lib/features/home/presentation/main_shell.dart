import 'package:flutter/material.dart';

import '../../backup/application/backup_controller.dart';
import '../../backup/presentation/backup_panel.dart';
import '../../ledger/application/ledger_controller.dart';
import 'home_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({
    required this.ledgerController,
    required this.backupController,
    super.key,
  });

  final LedgerController ledgerController;
  final BackupController backupController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HomeScreen(controller: ledgerController),
        PositionedDirectional(
          start: 16,
          bottom: 16,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: backupController,
              builder: (context, _) {
                final connected = backupController.isGoogleConnected;
                final hasBackup = backupController.lastSuccessfulBackup != null;
                return FloatingActionButton.extended(
                  heroTag: 'cloud-backup',
                  onPressed: () => showBackupPanel(context, backupController),
                  icon: Icon(
                    hasBackup
                        ? Icons.cloud_done_outlined
                        : connected
                            ? Icons.cloud_sync_outlined
                            : Icons.cloud_off_outlined,
                  ),
                  label: Text(
                    hasBackup
                        ? 'النسخ الاحتياطي'
                        : connected
                            ? 'إعداد النسخ'
                            : 'حماية البيانات',
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
