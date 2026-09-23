enum LedgerEntryType {
  debt,
  payment;

  String get databaseValue => name;

  static LedgerEntryType fromDatabase(String value) {
    return switch (value) {
      'debt' => LedgerEntryType.debt,
      'payment' => LedgerEntryType.payment,
      _ => throw ArgumentError.value(value, 'value', 'Unknown ledger entry type'),
    };
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.description,
    this.notes,
  });

  final String id;
  final String customerId;
  final LedgerEntryType type;
  final int amount;
  final String? description;
  final String? notes;
  final DateTime createdAt;

  int get signedAmount => type == LedgerEntryType.debt ? amount : -amount;

  factory LedgerEntry.fromMap(Map<String, Object?> map) {
    return LedgerEntry(
      id: map['id']! as String,
      customerId: map['customer_id']! as String,
      type: LedgerEntryType.fromDatabase(map['type']! as String),
      amount: map['amount']! as int,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }
}
