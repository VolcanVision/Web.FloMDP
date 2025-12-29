class PurchasePayment {
  final int? id;
  final int purchaseId;
  final double amount;
  final String paidAt;
  final String? note;
  final DateTime? createdAt;

  PurchasePayment({
    this.id,
    required this.purchaseId,
    required this.amount,
    required this.paidAt,
    this.note,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'purchase_id': purchaseId,
      'amount': amount,
      'paid_at': paidAt,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory PurchasePayment.fromMap(Map<String, dynamic> map) {
    return PurchasePayment(
      id: map['id'],
      purchaseId: map['purchase_id'],
      amount: (map['amount'] as num).toDouble(),
      paidAt: map['paid_at'],
      note: map['note'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  PurchasePayment copyWith({
    int? id,
    int? purchaseId,
    double? amount,
    String? paidAt,
    String? note,
    DateTime? createdAt,
  }) {
    return PurchasePayment(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
