class AdvancePayment {
  final int? id; // bigint in database
  final int orderId; // bigint, matches Order.id
  final double amount; // numeric(12, 2) in database
  final String paidAt; // date field, stored as YYYY-MM-DD string
  final String? note; // text field (optional)
  final DateTime? createdAt; // timestamp with time zone

  AdvancePayment({
    this.id,
    required this.orderId,
    required this.amount,
    required this.paidAt,
    this.note,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'order_id': orderId,
      'amount': amount,
      'paid_at': paidAt,
    };

    // Only include optional fields if they have values
    if (id != null) map['id'] = id;
    if (note != null) map['note'] = note;
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();

    return map;
  }

  factory AdvancePayment.fromMap(Map<String, dynamic> map) {
    return AdvancePayment(
      id: map['id'],
      orderId: map['order_id'],
      amount: (map['amount'] as num).toDouble(),
      paidAt: map['paid_at'],
      note: map['note'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  AdvancePayment copyWith({
    int? id,
    int? orderId,
    double? amount,
    String? paidAt,
    String? note,
    DateTime? createdAt,
  }) {
    return AdvancePayment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
