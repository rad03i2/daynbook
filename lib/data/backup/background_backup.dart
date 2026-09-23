import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import 'backup_coordinator.dart';

const String daynBookPeriodicBackupTask = 'daynbook.periodic-backup';
const String daynBookPeriodicBackupUniqueName = 'daynbook-hourly-cloud-backup';

@pragma('vm:entry-point')
void daynBookWorkmanagerDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    DartPluginRegistrant.ensureInitialized();

    if (taskName != daynBookPeriodicBackupTask) {
      return true;
    }

    final coordinator = BackupCoordinator();
    try {
      if (!await coordinator.hasStoredPassphrase()) {
        return true;
      }
      await coordinator.initialize();
      return coordinator.runBackgroundBackup();
    } catch (_) {
      return false;
    } finally {
      await coordinator.dispose();
    }
  });
}

Future<void> initializeBackgroundBackup() async {
  await Workmanager().initialize(daynBookWorkmanagerDispatcher);
  await Workmanager().registerPeriodicTask(
    daynBookPeriodicBackupUniqueName,
    daynBookPeriodicBackupTask,
    frequency: const Duration(hours: 1),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
      requiresStorageNotLow: true,
    ),
    tag: 'daynbook-backup',
  );
}
