class ProductionBatchOrder {
  int? id;
  int orderId;
  String batchNo;
  String? batchDetails;
  DateTime? createdAt;
  DateTime? updatedAt;

  ProductionBatchOrder({
    this.id,
    required this.orderId,
    required this.batchNo,
    this.batchDetails,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'batch_no': batchNo,
      'details':
          batchDetails, // Database column is 'details', not 'batch_details'
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ProductionBatchOrder.fromMap(Map<String, dynamic> map) {
    return ProductionBatchOrder(
      id: map['id'],
      orderId: map['order_id'],
      batchNo: map['batch_no'] ?? '',
      batchDetails:
          map['details'], // Database column is 'details', not 'batch_details'
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }
}
