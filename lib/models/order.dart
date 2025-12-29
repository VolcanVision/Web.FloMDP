class Order {
  final int? id;
  final String? orderNumber;
  final int? customerId;
  final String? clientName;
  final double advancePaid;
  final String dueDate;
  final String? dispatchDate;
  final bool isAdvancePaid;
  final String? advancePaymentDate;
  final int afterDispatchDays;
  final String? finalDueDate;
  final String? finalPaymentDate;
  final String orderStatus;
  final String paymentStatus;
  final String productionStatus;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double totalAmount;

  final String? location;

  Order({
    this.id,
    this.orderNumber,
    this.customerId,
    this.clientName,
    this.advancePaid = 0,
    required this.dueDate,
    this.dispatchDate,
    this.isAdvancePaid = false,
    this.advancePaymentDate,
    this.afterDispatchDays = 0,
    this.finalDueDate,
    this.finalPaymentDate,
    this.orderStatus = 'pending',
    this.paymentStatus = 'unpaid',
    this.productionStatus = 'created',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.totalAmount = 0.0,
    this.location,
  });

  double get pendingAmount => totalAmount - advancePaid;

  Map<String, dynamic> toMap() {
    final map = {
      'order_number': orderNumber,
      'client_name': clientName,
      'advance_paid': advancePaid,
      'is_advance_paid': isAdvancePaid,
      'advance_payment_date': advancePaymentDate,
      'due_date': dueDate,
      'dispatch_date': dispatchDate,
      'after_dispatch_days': afterDispatchDays,
      'final_due_date': finalDueDate,
      'final_payment_date': finalPaymentDate,
      'order_status': orderStatus,
      'payment_status': paymentStatus,
      'production_status': productionStatus,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'total_amount': totalAmount,
      'location': location,
    };
    // Only include id if it's not null (for updates, not inserts)
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      orderNumber: map['order_number'],
      customerId: null,
      clientName: map['client_name'],
      advancePaid: map['advance_paid']?.toDouble() ?? 0.0,
      dueDate: map['due_date'] ?? '',
      dispatchDate: map['dispatch_date'],
      isAdvancePaid: map['is_advance_paid'] ?? false,
      advancePaymentDate: map['advance_payment_date'],
      afterDispatchDays: map['after_dispatch_days'] ?? 0,
      finalDueDate: map['final_due_date'],
      finalPaymentDate: map['final_payment_date'],
      orderStatus: map['order_status'] ?? 'pending',
      paymentStatus: map['payment_status'] ?? 'unpaid',
      productionStatus: map['production_status'] ?? 'created',
      createdBy: map['created_by'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      location: map['location'],
    );
  }
  Order copyWith({
    int? id,
    String? orderNumber,
    int? customerId,
    String? clientName,
    double? advancePaid,
    String? dueDate,
    String? dispatchDate,
    bool? isAdvancePaid,
    String? advancePaymentDate,
    int? afterDispatchDays,
    String? finalDueDate,
    String? finalPaymentDate,
    String? orderStatus,
    String? paymentStatus,
    String? productionStatus,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? totalAmount,
    String? location,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      clientName: clientName ?? this.clientName,
      advancePaid: advancePaid ?? this.advancePaid,
      dueDate: dueDate ?? this.dueDate,
      dispatchDate: dispatchDate ?? this.dispatchDate,
      isAdvancePaid: isAdvancePaid ?? this.isAdvancePaid,
      advancePaymentDate: advancePaymentDate ?? this.advancePaymentDate,
      afterDispatchDays: afterDispatchDays ?? this.afterDispatchDays,
      finalDueDate: finalDueDate ?? this.finalDueDate,
      finalPaymentDate: finalPaymentDate ?? this.finalPaymentDate,
      orderStatus: orderStatus ?? this.orderStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      productionStatus: productionStatus ?? this.productionStatus,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalAmount: totalAmount ?? this.totalAmount,
      location: location ?? this.location,
    );
  }
}
