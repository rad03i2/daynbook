class CustomerAccount {
  const CustomerAccount({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.notes,
    this.balance = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final int balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasDebt => balance > 0;

  CustomerAccount copyWith({
    String? id,
    String? name,
    String? phone,
    String? notes,
    int? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CustomerAccount.fromMap(Map<String, Object?> map) {
    return CustomerAccount(
      id: map['id']! as String,
      name: map['name']! as String,
      phone: map['phone'] as String?,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    );
  }
}
