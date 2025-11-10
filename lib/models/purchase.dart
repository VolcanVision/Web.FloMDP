class Purchase {
  final int? id;
  final String companyName;
  final String material;
  final double? quantity;
  final double? cost;
  final double? totalAmount; // Computed in database
  final DateTime? purchaseDate;
  final String? notes;
  final DateTime? createdAt;
  final String? paymentStatus;
  final DateTime? paymentDueDate;

  Purchase({
    this.id,
    required this.companyName,
    required this.material,
    this.quantity,
    this.cost,
    this.totalAmount,
    this.purchaseDate,
    this.notes,
    this.createdAt,
    this.paymentStatus,
    this.paymentDueDate,
  });

  factory Purchase.fromMap(Map<String, dynamic> map) {
    return Purchase(
      id: map['id'] as int?,
      companyName: map['company_name'] as String? ?? '',
      material: map['material'] as String? ?? '',
      quantity: map['quantity'] != null ? (map['quantity'] as num).toDouble() : null,
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      totalAmount: map['total_amount'] != null ? (map['total_amount'] as num).toDouble() : null,
      purchaseDate: map['purchase_date'] != null 
          ? DateTime.parse(map['purchase_date'] as String)
          : null,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : null,
      paymentStatus: map['payment_status'] as String?,
      paymentDueDate: map['payment_due_date'] != null 
          ? DateTime.parse(map['payment_due_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'company_name': companyName,
      'material': material,
      if (quantity != null) 'quantity': quantity,
      if (cost != null) 'cost': cost,
      // Don't include total_amount - it's computed in database
      if (purchaseDate != null) 'purchase_date': purchaseDate!.toIso8601String().split('T')[0],
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paymentDueDate != null) 'payment_due_date': paymentDueDate!.toIso8601String().split('T')[0],
    };
  }

  Purchase copyWith({
    int? id,
    String? companyName,
    String? material,
    double? quantity,
    double? cost,
    double? totalAmount,
    DateTime? purchaseDate,
    String? notes,
    DateTime? createdAt,
    String? paymentStatus,
    DateTime? paymentDueDate,
  }) {
    return Purchase(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      material: material ?? this.material,
      quantity: quantity ?? this.quantity,
      cost: cost ?? this.cost,
      totalAmount: totalAmount ?? this.totalAmount,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentDueDate: paymentDueDate ?? this.paymentDueDate,
    );
  }
}
