import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/backup/google_drive_backup_service.dart';
import '../application/backup_controller.dart';

Future<void> showBackupPanel(
  BuildContext context,
  BackupController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BackupPanel(controller: controller),
  );
}

class BackupPanel extends StatelessWidget {
  const BackupPanel({required this.controller, super.key});

  final BackupController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الحماية السحابية',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const Text('نسخ مشفر إلى مساحة DaynBook الخاصة في Google Drive'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (controller.isBusy) const LinearProgressIndicator(),
                if (controller.lastError != null) ...[
                  const SizedBox(height: 12),
                  _MessageCard(
                    icon: Icons.error_outline,
                    text: controller.lastError!,
                  ),
                ],
                const SizedBox(height: 12),
                _StatusCard(controller: controller),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!controller.isGoogleConnected)
                      FilledButton.icon(
                        onPressed: controller.isBusy
                            ? null
                            : () => _run(
                                  context,
                                  controller.signIn,
                                  success: 'تم ربط حساب Google.',
                                ),
                        icon: const Icon(Icons.login),
                        label: const Text('ربط حساب Google'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: controller.isBusy
                            ? null
                            : () => _run(
                                  context,
                                  controller.signOut,
                                  success: 'تم فصل حساب Google من التطبيق.',
                                ),
                        icon: const Icon(Icons.logout),
                        label: const Text('فصل الحساب'),
                      ),
                    OutlinedButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => _configurePassphrase(context),
                      icon: const Icon(Icons.key_outlined),
                      label: Text(
                        controller.hasPassphrase
                            ? 'تغيير عبارة الحماية'
                            : 'تعيين عبارة الحماية',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => _backupNow(context),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('نسخ الآن'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy
                          ? null
                          : () => _restoreLatest(context),
                      icon: const Icon(Icons.settings_backup_restore),
                      label: const Text('استعادة أحدث نسخة'),
                    ),
                    TextButton.icon(
                      onPressed: controller.isBusy || !controller.isGoogleConnected
                          ? null
                          : () => _run(
                                context,
                                controller.loadRemoteBackups,
                              ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث قائمة النسخ'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'النسخ المتوفرة',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Expanded(child: _BackupList(controller: controller)),
                const SizedBox(height: 8),
                const _MessageCard(
                  icon: Icons.info_outline,
                  text:
                      'احتفظ بعبارة الحماية في مكان آمن. Google لا يملك المفتاح، وإذا فقدت العبارة بعد فقدان الجهاز فلن يمكن فك النسخة المشفرة.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _configurePassphrase(BuildContext context) async {
    final value = await _askPassphrase(
      context,
      title: controller.hasPassphrase
          ? 'تغيير عبارة حماية النسخ'
          : 'تعيين عبارة حماية النسخ',
      confirmation: true,
    );
    if (value == null || !context.mounted) return;
    await _run(
      context,
      () => controller.setPassphrase(value),
      success: 'تم حفظ عبارة الحماية بأمان على هذا الجهاز.',
    );
  }

  Future<void> _backupNow(BuildContext context) async {
    String? passphrase;
    if (!controller.hasPassphrase) {
      passphrase = await _askPassphrase(
        context,
        title: 'عبارة حماية النسخة',
        confirmation: true,
      );
      if (passphrase == null || !context.mounted) return;
    }

    await _run(
      context,
      () => controller.backupNow(passphrase: passphrase),
      success: 'اكتمل النسخ المشفر إلى Google Drive.',
    );
  }

  Future<void> _restoreLatest(BuildContext context) async {
    final confirmed = await _confirmRestore(context);
    if (!confirmed || !context.mounted) return;

    String? passphrase;
    if (!controller.hasPassphrase) {
      passphrase = await _askPassphrase(
        context,
        title: 'عبارة حماية النسخة القديمة',
      );
      if (passphrase == null || !context.mounted) return;
    }

    await _run(
      context,
      () => controller.restoreLatest(passphrase: passphrase),
      success: 'تمت استعادة أحدث نسخة بنجاح.',
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final BackupController controller;

  @override
  Widget build(BuildContext context) {
    final last = controller.lastSuccessfulBackup;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusRow(
              icon: Icons.account_circle_outlined,
              label: 'حساب Google',
              value: controller.email ?? 'غير مربوط',
            ),
            const SizedBox(height: 10),
            _StatusRow(
              icon: Icons.lock_outline,
              label: 'التشفير',
              value: controller.hasPassphrase ? 'مفعّل' : 'غير مُعد',
            ),
            const SizedBox(height: 10),
            _StatusRow(
              icon: Icons.schedule,
              label: 'آخر نسخة ناجحة',
              value: last == null ? 'لا توجد بعد' : _formatDate(last),
            ),
            const SizedBox(height: 10),
            const _StatusRow(
              icon: Icons.autorenew,
              label: 'النسخ التلقائي',
              value: 'كل ساعة عند توفر الإنترنت',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _BackupList extends StatelessWidget {
  const _BackupList({required this.controller});

  final BackupController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isGoogleConnected) {
      return const Center(child: Text('اربط حساب Google لعرض النسخ السحابية.'));
    }
    if (controller.remoteBackups.isEmpty) {
      return const Center(
        child: Text('لا توجد نسخ محمّلة في القائمة. اضغط تحديث أو أنشئ نسخة.'),
      );
    }

    return ListView.separated(
      itemCount: controller.remoteBackups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final backup = controller.remoteBackups[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.cloud_done_outlined)),
            title: Text(index == 0 ? 'أحدث نسخة' : 'نسخة سابقة'),
            subtitle: Text(
              '${_formatDate(backup.modifiedTime.toLocal())}\n${_formatSize(backup.size)}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'استعادة هذه النسخة',
              icon: const Icon(Icons.restore),
              onPressed: controller.isBusy
                  ? null
                  : () => _restoreBackup(context, controller, backup),
            ),
          ),
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

Future<void> _restoreBackup(
  BuildContext context,
  BackupController controller,
  RemoteBackup backup,
) async {
  final confirmed = await _confirmRestore(context);
  if (!confirmed || !context.mounted) return;

  String? passphrase;
  if (!controller.hasPassphrase) {
    passphrase = await _askPassphrase(
      context,
      title: 'عبارة حماية هذه النسخة',
    );
    if (passphrase == null || !context.mounted) return;
  }

  await _run(
    context,
    () => controller.restore(backup, passphrase: passphrase),
    success: 'تمت استعادة النسخة المحددة بنجاح.',
  );
}

Future<bool> _confirmRestore(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الاستعادة'),
          content: const Text(
            'ستستبدل الاستعادة الزبائن والحركات الموجودة حاليًا بالبيانات الموجودة في النسخة السحابية. يُفضّل إنشاء نسخة جديدة قبل المتابعة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<String?> _askPassphrase(
  BuildContext context, {
  required String title,
  bool confirmation = false,
}) async {
  final first = TextEditingController();
  final second = TextEditingController();
  String? error;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'عبارة الحماية (8 أحرف على الأقل)',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (confirmation) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: second,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد عبارة الحماية',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = first.text;
              if (value.trim().length < 8) {
                setState(() => error = 'العبارة قصيرة جدًا.');
                return;
              }
              if (confirmation && value != second.text) {
                setState(() => error = 'عبارتا الحماية غير متطابقتين.');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    ),
  );

  first.dispose();
  second.dispose();
  return result;
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (!context.mounted || success == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر إكمال العملية. راجع الحالة وحاول مجددًا.')),
    );
  }
}

String _formatDate(DateTime value) {
  return DateFormat('yyyy/MM/dd  HH:mm', 'ar_IQ').format(value);
}

String _formatSize(int? bytes) {
  if (bytes == null) return 'الحجم غير متوفر';
  if (bytes < 1024) return '$bytes بايت';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} كيلوبايت';
  return '${(kb / 1024).toStringAsFixed(1)} ميغابايت';
}
