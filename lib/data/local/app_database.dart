import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/customer.dart';
import '../../core/models/ledger_entry.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _databaseName = 'daynbook.db';
  static const _databaseVersion = 1;
  static const _uuid = Uuid();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _databaseName);

    final opened = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );

    _database = opened;
    return opened;
  }

  Future<String> get databaseFilePath async {
    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, _databaseName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('debt', 'payment')),
        amount INTEGER NOT NULL CHECK(amount > 0),
        description TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_transactions_customer ON transactions(customer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_created ON transactions(created_at DESC)',
    );
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
  }

  Future<List<CustomerAccount>> getCustomers({String search = ''}) async {
    final db = await database;
    final term = '%${search.trim()}%';
    final rows = await db.rawQuery(
      '''
      SELECT
        c.id,
        c.name,
        c.phone,
        c.notes,
        c.created_at,
        c.updated_at,
        COALESCE(
          SUM(
            CASE
              WHEN t.type = 'debt' THEN t.amount
              WHEN t.type = 'payment' THEN -t.amount
              ELSE 0
            END
          ),
          0
        ) AS balance
      FROM customers c
      LEFT JOIN transactions t ON t.customer_id = c.id
      WHERE c.name LIKE ? OR COALESCE(c.phone, '') LIKE ?
      GROUP BY c.id
      ORDER BY c.updated_at DESC, c.name COLLATE NOCASE ASC
      ''',
      [term, term],
    );

    return rows.map(CustomerAccount.fromMap).toList(growable: false);
  }

  Future<CustomerAccount> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Customer name cannot be empty');
    }

    final db = await database;
    final now = DateTime.now();
    final id = _uuid.v7();

    await db.insert('customers', {
      'id': id,
      'name': trimmedName,
      'phone': _emptyToNull(phone),
      'notes': _emptyToNull(notes),
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });

    return CustomerAccount(
      id: id,
      name: trimmedName,
      phone: _emptyToNull(phone),
      notes: _emptyToNull(notes),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<LedgerEntry>> getEntries(String customerId) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    return rows.map(LedgerEntry.fromMap).toList(growable: false);
  }

  Future<LedgerEntry> addEntry({
    required String customerId,
    required LedgerEntryType type,
    required int amount,
    String? description,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be greater than zero');
    }

    final db = await database;
    final id = _uuid.v7();
    final now = DateTime.now();

    await db.transaction((txn) async {
      final customerCount = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM customers WHERE id = ?',
          [customerId],
        ),
      );
      if (customerCount != 1) {
        throw StateError('Customer does not exist');
      }

      await txn.insert('transactions', {
        'id': id,
        'customer_id': customerId,
        'type': type.databaseValue,
        'amount': amount,
        'description': _emptyToNull(description),
        'notes': _emptyToNull(notes),
        'created_at': now.millisecondsSinceEpoch,
      });

      await txn.update(
        'customers',
        {'updated_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [customerId],
      );
    });

    return LedgerEntry(
      id: id,
      customerId: customerId,
      type: type,
      amount: amount,
      description: _emptyToNull(description),
      notes: _emptyToNull(notes),
      createdAt: now,
    );
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) await db.close();
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
