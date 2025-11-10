class OrderInstallment {
  int? id;
  int orderId;
  int installmentNumber;
  double amount;
  String dueDate;
  bool isPaid;
  String? paidDate;
  String? notes;
  DateTime? createdAt;
  DateTime? updatedAt;

  OrderInstallment({
    this.id,
    required this.orderId,
    required this.installmentNumber,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.paidDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // Convert OrderInstallment to Map for database operations
  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'order_id': orderId,
      'installment_number': installmentNumber,
      'amount': amount,
      'due_date': dueDate,
      'is_paid': isPaid,
      'paid_date': paidDate,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    if (includeId && id != null) {
      map['id'] = id;
    }

    return map;
  }

  // Create OrderInstallment from Map (database result)
  factory OrderInstallment.fromMap(Map<String, dynamic> map) {
    return OrderInstallment(
      id: map['id'],
      orderId: map['order_id'],
      installmentNumber: map['installment_number'],
      amount: map['amount']?.toDouble() ?? 0.0,
      dueDate: map['due_date'] ?? '',
      isPaid: map['is_paid'] ?? false,
      paidDate: map['paid_date'],
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
  OrderInstallment copyWith({
    int? id,
    int? orderId,
    int? installmentNumber,
    double? amount,
    String? dueDate,
    bool? isPaid,
    String? paidDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderInstallment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
