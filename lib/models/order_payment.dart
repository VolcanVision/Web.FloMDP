class OrderPayment {
  int? id;
  int orderId;
  double amount;
  String paymentDate;
  String paymentMethod;
  String? referenceNumber;
  String? notes;
  DateTime? createdAt;
  DateTime? updatedAt;

  OrderPayment({
    this.id,
    required this.orderId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = 'cash',
    this.referenceNumber,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // Convert OrderPayment to Map for database operations
  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'order_id': orderId,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    if (includeId && id != null) {
      map['id'] = id;
    }

    return map;
  }

  // Create OrderPayment from Map (database result)
  factory OrderPayment.fromMap(Map<String, dynamic> map) {
    return OrderPayment(
      id: map['id'],
      orderId: map['order_id'],
      amount: map['amount']?.toDouble() ?? 0.0,
      paymentDate: map['payment_date'] ?? '',
      paymentMethod: map['payment_method'] ?? 'cash',
      referenceNumber: map['reference_number'],
      notes: map['notes'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  // Create a copy with updated fields
  OrderPayment copyWith({
    int? id,
    int? orderId,
    double? amount,
    String? paymentDate,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderPayment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
