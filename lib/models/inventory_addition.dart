/// Model for tracking inventory additions with date
class InventoryAddition {
  int? id;
  int inventoryItemId;
  String itemName;
  double quantity;
  DateTime additionDate;
  String? supplier;
  String? notes;
  String? addedBy;
  DateTime? createdAt;

  // Joined fields from inventory_items (optional)
  String? itemType;
  String? itemCategory;

  InventoryAddition({
    this.id,
    required this.inventoryItemId,
    required this.itemName,
    required this.quantity,
    required this.additionDate,
    this.supplier,
    this.notes,
    this.addedBy,
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
      'addition_date': additionDate.toIso8601String().split('T')[0],
      'supplier': supplier,
      'notes': notes,
      'added_by': addedBy,
    };
  }

  factory InventoryAddition.fromMap(Map<String, dynamic> map) {
    return InventoryAddition(
      id: map['id'],
      inventoryItemId: map['inventory_item_id'] ?? 0,
      itemName: map['item_name'] ?? '',
      quantity: _parseDouble(map['quantity']),
      additionDate: _parseDate(map['addition_date']),
      supplier: map['supplier'],
      notes: map['notes'],
      addedBy: map['added_by'],
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
