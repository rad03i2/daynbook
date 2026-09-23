import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart';
import '../../ledger/application/ledger_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.controller, super.key});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('دفتر الدين'),
                Text(
                  'إدارة حسابات الزبائن',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Center(
                  child: Text(
                    'إجمالي الديون: ${_money(controller.totalOutstanding)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 850;
                if (isTablet) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 370,
                        child: _CustomersPane(controller: controller),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _CustomerDetails(
                          controller: controller,
                          showBackButton: false,
                        ),
                      ),
                    ],
                  );
                }

                if (controller.selectedCustomer != null) {
                  return _CustomerDetails(
                    controller: controller,
                    showBackButton: true,
                  );
                }
                return _CustomersPane(controller: controller);
              },
            ),
          ),
        );
      },
    );
  }
}

class _CustomersPane extends StatelessWidget {
  const _CustomersPane({required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => controller.loadCustomers(search: value),
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم أو رقم الهاتف',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'إضافة زبون',
                onPressed: () => _showAddCustomerDialog(context, controller),
                icon: const Icon(Icons.person_add_alt_1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (controller.lastError != null)
            _ErrorCard(message: 'تعذر تحميل البيانات. حاول مرة أخرى.'),
          if (controller.isLoading && controller.customers.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.customers.isEmpty)
            Expanded(
              child: _EmptyCustomers(
                onAdd: () => _showAddCustomerDialog(context, controller),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: controller.customers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final customer = controller.customers[index];
                  final selected = controller.selectedCustomer?.id == customer.id;
                  return Card(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      onTap: () => controller.selectCustomer(customer),
                      leading: CircleAvatar(
                        child: Text(customer.name.characters.first),
                      ),
                      title: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(customer.phone ?? 'بدون رقم هاتف'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _money(customer.balance.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: customer.balance > 0
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            customer.balance > 0
                                ? 'مطلوب'
                                : customer.balance < 0
                                    ? 'رصيد زائد'
                                    : 'مسدد',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerDetails extends StatelessWidget {
  const _CustomerDetails({
    required this.controller,
    required this.showBackButton,
  });

  final LedgerController controller;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final customer = controller.selectedCustomer;
    if (customer == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 64),
            SizedBox(height: 12),
            Text('اختر زبونًا لعرض دفتر حسابه'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  onPressed: controller.clearSelection,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'رجوع',
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (customer.phone != null) Text(customer.phone!),
                  ],
                ),
              ),
              _BalanceCard(customer: customer),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showEntryDialog(
                    context,
                    controller,
                    LedgerEntryType.debt,
                  ),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('تسجيل دين'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _showEntryDialog(
                    context,
                    controller,
                    LedgerEntryType.payment,
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('تسديد دفعة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'سجل الحركات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (controller.isLoading)
            const LinearProgressIndicator()
          else if (controller.entries.isEmpty)
            const Expanded(
              child: Center(child: Text('لا توجد حركات مسجلة لهذا الزبون بعد.')),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: controller.entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = controller.entries[index];
                  final isDebt = entry.type == LedgerEntryType.debt;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      child: Icon(isDebt ? Icons.add : Icons.remove),
                    ),
                    title: Text(entry.description ?? (isDebt ? 'دين' : 'تسديد')),
                    subtitle: Text(_date(entry.createdAt)),
                    trailing: Text(
                      '${isDebt ? '+' : '-'} ${_money(entry.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDebt
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.customer});

  final CustomerAccount customer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('الرصيد الحالي'),
            Text(
              _money(customer.balance),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 64),
          const SizedBox(height: 12),
          const Text('لا يوجد زبائن بعد'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('إضافة أول زبون'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _CustomerDraft {
  const _CustomerDraft(this.name, this.phone, this.notes);

  final String name;
  final String phone;
  final String notes;
}

class _EntryDraft {
  const _EntryDraft(this.amount, this.description, this.notes);

  final int amount;
  final String description;
  final String notes;
}

Future<void> _showAddCustomerDialog(
  BuildContext context,
  LedgerController controller,
) async {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final notesController = TextEditingController();

  final draft = await showDialog<_CustomerDraft>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('إضافة زبون'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'اسم الزبون *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
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
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(
                dialogContext,
                _CustomerDraft(
                  nameController.text,
                  phoneController.text,
                  notesController.text,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      );
    },
  );

  nameController.dispose();
  phoneController.dispose();
  notesController.dispose();

  if (draft == null || !context.mounted) return;

  try {
    await controller.createCustomer(
      name: draft.name,
      phone: draft.phone,
      notes: draft.notes,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر حفظ الزبون. حاول مرة أخرى.')),
    );
  }
}

Future<void> _showEntryDialog(
  BuildContext context,
  LedgerController controller,
  LedgerEntryType type,
) async {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final notesController = TextEditingController();
  final isDebt = type == LedgerEntryType.debt;

  final draft = await showDialog<_EntryDraft>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(isDebt ? 'تسجيل دين جديد' : 'تسجيل تسديد'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹,٬ ]'))],
                decoration: const InputDecoration(
                  labelText: 'المبلغ بالدينار العراقي *',
                  suffixText: 'د.ع',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: isDebt ? 'البضاعة أو الوصف' : 'وصف التسديد',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
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
              final normalized = _normalizeDigits(amountController.text)
                  .replaceAll(',', '')
                  .replaceAll('٬', '')
                  .replaceAll(' ', '');
              final amount = int.tryParse(normalized);
              if (amount == null || amount <= 0) return;
              Navigator.pop(
                dialogContext,
                _EntryDraft(
                  amount,
                  descriptionController.text,
                  notesController.text,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      );
    },
  );

  amountController.dispose();
  descriptionController.dispose();
  notesController.dispose();

  if (draft == null || !context.mounted) return;

  try {
    await controller.addEntry(
      type: type,
      amount: draft.amount,
      description: draft.description,
      notes: draft.notes,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر حفظ الحركة. حاول مرة أخرى.')),
    );
  }
}

String _money(int value) {
  final formatter = NumberFormat.decimalPattern('en_US');
  return '${formatter.format(value)} د.ع';
}

String _date(DateTime value) {
  return DateFormat('yyyy/MM/dd - HH:mm').format(value);
}

String _normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var output = value;
  for (var i = 0; i < 10; i++) {
    output = output.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return output;
}
