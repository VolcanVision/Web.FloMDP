class Shipment {
  int? id;
  int orderId;
  String shippedAt;
  DateTime? createdAt;

  Shipment({
    this.id,
    required this.orderId,
    required this.shippedAt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'shipped_at': shippedAt,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Shipment.fromMap(Map<String, dynamic> map) {
    return Shipment(
      id: map['id'],
      orderId: map['order_id'],
      shippedAt: map['shipped_at'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }
}
