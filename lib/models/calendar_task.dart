enum TaskCategory { admin, production, accounts }

class CalendarTask {
  int? id;
  String title;
  String description;
  DateTime date;
  TaskCategory category;
  bool isCompleted;
  int? assignedTo;
  String? assignedBy; // UUID of user who assigned the task
  int? orderId;
  int? createdBy;
  DateTime? createdAt;
  DateTime? updatedAt;

  CalendarTask({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    this.isCompleted = false,
    this.assignedTo,
    this.assignedBy,
    this.orderId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  // Convert CalendarTask to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'task_date': date.toIso8601String().split('T')[0], // Date only
      'category': category.name,
      'is_completed': isCompleted,
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'order_id': orderId,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create CalendarTask from Map (database result)
  factory CalendarTask.fromMap(Map<String, dynamic> map) {
    return CalendarTask(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: DateTime.parse(map['task_date']),
      category: TaskCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => TaskCategory.production,
      ),
      isCompleted: map['is_completed'] == true || map['is_completed'] == 1,
      assignedTo: map['assigned_to'],
      assignedBy: map['assigned_by'],
      orderId: map['order_id'],
      createdBy: map['created_by'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }
}
