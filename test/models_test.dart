import 'package:daynbook/core/models/customer.dart';
import 'package:daynbook/core/models/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LedgerEntry', () {
    test('debt has positive signed amount', () {
      final entry = LedgerEntry(
        id: 'entry-1',
        customerId: 'customer-1',
        type: LedgerEntryType.debt,
        amount: 25000,
        createdAt: DateTime(2026, 9, 24),
      );

      expect(entry.signedAmount, 25000);
    });

    test('payment has negative signed amount', () {
      final entry = LedgerEntry(
        id: 'entry-2',
        customerId: 'customer-1',
        type: LedgerEntryType.payment,
        amount: 10000,
        createdAt: DateTime(2026, 9, 24),
      );

      expect(entry.signedAmount, -10000);
    });
  });

  test('customer debt flag follows balance', () {
    final customer = CustomerAccount(
      id: 'customer-1',
      name: 'زبون تجريبي',
      balance: 5000,
      createdAt: DateTime(2026, 9, 24),
      updatedAt: DateTime(2026, 9, 24),
    );

    expect(customer.hasDebt, isTrue);
  });
}
