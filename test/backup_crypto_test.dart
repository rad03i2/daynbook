import 'package:daynbook/data/backup/backup_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupCrypto', () {
    test('encrypts and decrypts a snapshot without losing data', () async {
      final crypto = BackupCrypto();
      final snapshot = <String, dynamic>{
        'schemaVersion': 1,
        'exportedAt': '2026-09-24T00:00:00.000Z',
        'customers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'customer-1',
            'name': 'أحمد',
            'phone': '07700000000',
            'notes': null,
            'created_at': 1,
            'updated_at': 2,
          },
        ],
        'transactions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'transaction-1',
            'customer_id': 'customer-1',
            'type': 'debt',
            'amount': 25000,
            'description': 'مواد غذائية',
            'notes': null,
            'created_at': 3,
          },
        ],
      };

      final encrypted = await crypto.encryptSnapshot(
        snapshot,
        passphrase: 'strong-passphrase-123',
      );
      final restored = await crypto.decryptSnapshot(
        encrypted,
        passphrase: 'strong-passphrase-123',
      );

      final customers = restored['customers'] as List<dynamic>;
      final transactions = restored['transactions'] as List<dynamic>;
      expect(restored['schemaVersion'], 1);
      expect((customers.single as Map<String, dynamic>)['name'], 'أحمد');
      expect(
        (transactions.single as Map<String, dynamic>)['amount'],
        25000,
      );
    });

    test('rejects an incorrect passphrase', () async {
      final crypto = BackupCrypto();
      final encrypted = await crypto.encryptSnapshot(
        <String, dynamic>{
          'schemaVersion': 1,
          'customers': <Map<String, dynamic>>[],
          'transactions': <Map<String, dynamic>>[],
        },
        passphrase: 'correct-passphrase',
      );

      await expectLater(
        crypto.decryptSnapshot(
          encrypted,
          passphrase: 'incorrect-passphrase',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('requires a passphrase of at least eight characters', () async {
      final crypto = BackupCrypto();

      await expectLater(
        crypto.encryptSnapshot(
          <String, dynamic>{'schemaVersion': 1},
          passphrase: '1234',
        ),
        throwsArgumentError,
      );
    });
  });
}
