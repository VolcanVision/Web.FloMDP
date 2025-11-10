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
    );
  }
}
