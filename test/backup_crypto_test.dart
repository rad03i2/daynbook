import 'package:daynbook/data/backup/backup_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupCrypto', () {
    test('encrypts and decrypts a snapshot without losing data', () async {
      final crypto = BackupCrypto();
      final snapshot = <String, dynamic>{
        'schemaVersion': 1,
        'exportedAt': '2026-09-24T00:00:00.000Z',
        'customers': [
          {
            'id': 'customer-1',
            'name': 'أحمد',
            'phone': '07700000000',
            'notes': null,
            'created_at': 1,
            'updated_at': 2,
          },
        ],
        'transactions': [
          {
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

      expect(restored['schemaVersion'], 1);
      expect((restored['customers'] as List).single['name'], 'أحمد');
      expect((restored['transactions'] as List).single['amount'], 25000);
    });

    test('rejects an incorrect passphrase', () async {
      final crypto = BackupCrypto();
      final encrypted = await crypto.encryptSnapshot(
        <String, dynamic>{
          'schemaVersion': 1,
          'customers': const [],
          'transactions': const [],
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
