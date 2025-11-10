import 'package:flutter/material.dart';

class ProductionQueue {
  final String id;
  final String batchNumber;
  final String inventoryId;
  final String status;
  final double progress;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const List<String> validStatuses = [
    'queued',
    'in_progress',
    'completed',
    'paused',
  ];

  ProductionQueue({
    required this.id,
    required this.batchNumber,
    required this.inventoryId,
    String? status,
    this.progress = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : status = status ?? 'queued',
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now() {
    // Validate status
    if (!validStatuses.contains(this.status)) {
      throw ArgumentError('Invalid status: ${this.status}');
    }
    // Validate progress
    if (progress < 0 || progress > 100) {
      throw ArgumentError('Progress must be between 0 and 100');
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'in_progress':
        return 'In Progress (${progress.toInt()}%)';
      case 'completed':
        return 'Completed';
      case 'queued':
        return 'Queued';
      case 'paused':
        return 'Paused';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'queued':
        return Colors.orange;
      case 'paused':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Database serialization methods
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_number': batchNumber,
      'inventory_id': inventoryId,
      'status': status,
      'progress': progress,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductionQueue.fromMap(Map<String, dynamic> map) {
    return ProductionQueue(
      id: map['id']?.toString() ?? '',
      batchNumber: map['batch_number']?.toString() ?? '',
      inventoryId: map['inventory_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'queued',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now(),
    );
  }

  ProductionQueue copyWith({
    String? id,
    String? batchNumber,
    String? inventoryId,
    String? status,
    double? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductionQueue(
      id: id ?? this.id,
      batchNumber: batchNumber ?? this.batchNumber,
      inventoryId: inventoryId ?? this.inventoryId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductionQueueItem {
  final String id;
  final String inventoryId;
  final String productName;
  final int quantity;
  final bool completed;
  final int queuePosition;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductionQueueItem({
    required this.id,
    required this.inventoryId,
    required this.productName,
    required this.quantity,
    this.completed = false,
    this.queuePosition = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Helper methods
  bool get canComplete => !completed;

  // Database serialization methods
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventory_id': inventoryId,
      'product_name': productName,
      'quantity': quantity,
      'completed': completed,
      'queue_position': queuePosition,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductionQueueItem.fromMap(Map<String, dynamic> map) {
    return ProductionQueueItem(
      id: map['id']?.toString() ?? '',
      inventoryId: map['inventory_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      completed: map['completed'] as bool? ?? false,
      queuePosition: (map['queue_position'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now(),
    );
  }

  ProductionQueueItem copyWith({
    String? id,
    String? inventoryId,
    String? productName,
    int? quantity,
    bool? completed,
    int? queuePosition,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductionQueueItem(
      id: id ?? this.id,
      inventoryId: inventoryId ?? this.inventoryId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      completed: completed ?? this.completed,
      queuePosition: queuePosition ?? this.queuePosition,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
