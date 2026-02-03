/// Model for tracking inventory consumptions with date
class InventoryConsumption {
  int? id;
  int inventoryItemId;
  String itemName;
  double quantity;
  DateTime consumptionDate;
  String? purpose;
  String? batchNo;
  String? notes;
  String? consumedBy;
  DateTime? createdAt;

  // Joined fields from inventory_items (optional)
  String? itemType;
  String? itemCategory;

  InventoryConsumption({
    this.id,
    required this.inventoryItemId,
    required this.itemName,
    required this.quantity,
    required this.consumptionDate,
    this.purpose,
    this.batchNo,
    this.notes,
    this.consumedBy,
    this.createdAt,
    this.itemType,
    this.itemCategory,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'inventory_item_id': inventoryItemId,
      'item_name': itemName,
      'quantity': quantity,
      'consumption_date': consumptionDate.toIso8601String().split('T')[0],
      'purpose': purpose,
      'batch_no': batchNo,
      'notes': notes,
      'consumed_by': consumedBy,
    };
  }

  factory InventoryConsumption.fromMap(Map<String, dynamic> map) {
    return InventoryConsumption(
      id: map['id'],
      inventoryItemId: map['inventory_item_id'] ?? 0,
      itemName: map['item_name'] ?? '',
      quantity: _parseDouble(map['quantity']),
      consumptionDate: _parseDate(map['consumption_date']),
      purpose: map['purpose'],
      batchNo: map['batch_no'],
      notes: map['notes'],
      consumedBy: map['consumed_by'],
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(map['created_at'])
              : null,
      itemType: map['item_type'],
      itemCategory: map['item_category'],
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
