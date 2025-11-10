class InventoryItem {
  int? id;
  String name;
  String type;
  double quantity;
  int? minQuantity; // Reflect min_quantity as nullable integer
  String category;
  DateTime? createdAt; // Optional: column may not exist in DB
  DateTime? updatedAt; // Optional: column may not exist in DB

  InventoryItem({
    this.id,
    required this.name,
    required this.type,
    required this.quantity,
    this.minQuantity, // Initialize minQuantity as nullable
    required this.category,
    this.createdAt,
    this.updatedAt,
  });

  // Convert InventoryItem to Map for database operations
  Map<String, dynamic> toMap({bool includeTimestampsIfPresent = true}) {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'category': category,
    };
    // Only include timestamp keys if the instance has values AND caller wants them.
    if (includeTimestampsIfPresent) {
      if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
      if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    }
    return map;
  }

  // Create InventoryItem from Map (database result)
  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    // Handle quantity conversion - database might return double or int
    double parseQuantity(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int? parseMinQuantity(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return InventoryItem(
      id: map['id'],
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      quantity: parseQuantity(map['quantity']),
      minQuantity: parseMinQuantity(map['min_quantity']),
      category: map['category'] ?? '',
      createdAt: map.containsKey('created_at') && map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      updatedAt: map.containsKey('updated_at') && map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
    );
  }
}
