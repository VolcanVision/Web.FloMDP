class OrderItem {
  final int? id;
  final int orderId;
  final String productName;
  final num quantity;
  final String? note;
  final DateTime? createdAt;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productName,
    required this.quantity,
    this.note,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'order_id': orderId,
      'product_name': productName,
      'quantity': quantity,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      productName: map['product_name'],
      quantity: map['quantity'] ?? 1,
      note: map['note'],
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
}
