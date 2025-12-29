enum TaskCategory { admin, production, accounts, labTesting }

enum RecurrenceType { none, daily, weekly, monthly }

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
  
  // Recurring task fields
  bool isRecurring;
  RecurrenceType recurrenceType;
  int recurrenceInterval; // e.g., every 1 day, 2 weeks, etc.
  DateTime? recurrenceEndDate;
  int? parentTaskId; // For generated instances, points to the original recurring task

  // Display-only fields (not stored in DB)
  String? assignedToName;
  String? assignedByName;

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
    this.isRecurring = false,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndDate,
    this.parentTaskId,
    this.assignedToName,
    this.assignedByName,
  });

  // Convert CalendarTask to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'task_date': date.toIso8601String().split('T')[0], // Date only
      // Map category - labTesting maps to 'production' as fallback since schema only allows admin/production/accounts
      'category': category == TaskCategory.labTesting ? 'production' : category.name,

      'is_completed': isCompleted,
      'assignee': assignedTo?.toString(), // Schema uses 'assignee' text
      'assigned_by': assignedBy,
      // 'order_id': orderId, // Removed: Not in schema

      // 'created_by': createdBy, // Removed: Not in schema
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_recurring': isRecurring,
      'recurrence_type': recurrenceType == RecurrenceType.none ? null : recurrenceType.name,

      'recurrence_interval': recurrenceInterval,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String().split('T')[0],
      'parent_task_id': parentTaskId,
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
        (e) => e.name == (map['category'] ?? 'production'),
        orElse: () => TaskCategory.production,
      ),
      isCompleted: map['is_completed'] == true || map['is_completed'] == 1,
      // Handle assignee parsing safely
      assignedTo: int.tryParse(map['assignee']?.toString() ?? ''),
      assignedBy: map['assigned_by'],
      orderId: map['order_id'],
      // createdBy: map['created_by'], // Removed: Not in schema
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      isRecurring: map['is_recurring'] == true || map['is_recurring'] == 1,
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == (map['recurrence_type'] ?? 'none'),
        orElse: () => RecurrenceType.none,
      ),
      recurrenceInterval: map['recurrence_interval'] ?? 1,
      recurrenceEndDate: map['recurrence_end_date'] != null
          ? DateTime.parse(map['recurrence_end_date'])
          : null,
      parentTaskId: map['parent_task_id'],
    );
  }
  
  /// Generate recurring task instances for a date range
  List<CalendarTask> generateRecurringInstances(DateTime rangeStart, DateTime rangeEnd) {
    if (!isRecurring || recurrenceType == RecurrenceType.none) return [];
    
    final instances = <CalendarTask>[];
    DateTime currentDate = date;
    final endDate = recurrenceEndDate ?? rangeEnd;
    
    // Optimization: if date is long before rangeStart, jump closer
    if (currentDate.isBefore(rangeStart)) {
      if (recurrenceType == RecurrenceType.daily) {
        final diff = rangeStart.difference(date).inDays;
        if (diff > recurrenceInterval) {
          final skip = (diff / recurrenceInterval).floor() * recurrenceInterval;
          currentDate = currentDate.add(Duration(days: skip));
        }
      } else if (recurrenceType == RecurrenceType.weekly) {
        final diff = rangeStart.difference(date).inDays;
        final weekDays = 7 * recurrenceInterval;
        if (diff > weekDays) {
          final skip = (diff / weekDays).floor() * weekDays;
          currentDate = currentDate.add(Duration(days: skip));
        }
      }
    }

    // Safety break to prevent infinite loops (extended for year+ ranges)
    int safetyCounter = 0;
    while ((currentDate.isBefore(rangeEnd) || currentDate.isAtSameMomentAs(rangeEnd)) &&
        safetyCounter < 1000) {
      safetyCounter++;
      if (currentDate.isAfter(endDate)) break;

      // Only add instances that are within the requested range 
      // AND are not the original task's date
      if ((currentDate.isAfter(rangeStart) || currentDate.isAtSameMomentAs(rangeStart)) &&
          (currentDate.year != date.year ||
              currentDate.month != date.month ||
              currentDate.day != date.day)) {
        instances.add(CalendarTask(

          id: null, // Generated instances don't have their own ID
          title: title,
          description: description,
          date: currentDate,
          category: category,
          isCompleted: false,
          assignedTo: assignedTo,
          assignedBy: assignedBy,
          orderId: orderId,
          createdBy: createdBy,
          isRecurring: true,
          recurrenceType: recurrenceType,
          recurrenceInterval: recurrenceInterval,
          recurrenceEndDate: recurrenceEndDate,
          parentTaskId: id,
        ));
      }
      
      // Calculate next occurrence
      switch (recurrenceType) {
        case RecurrenceType.daily:
          currentDate = currentDate.add(Duration(days: recurrenceInterval));
          break;
        case RecurrenceType.weekly:
          currentDate = currentDate.add(Duration(days: 7 * recurrenceInterval));
          break;
        case RecurrenceType.monthly:
          // Better monthly calculation
          int nextMonth = currentDate.month + recurrenceInterval;
          int nextYear = currentDate.year + (nextMonth - 1) ~/ 12;
          nextMonth = (nextMonth - 1) % 12 + 1;
          
          // Handle months with different number of days
          int lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          int nextDay = date.day > lastDayOfNextMonth ? lastDayOfNextMonth : date.day;
          
          currentDate = DateTime(nextYear, nextMonth, nextDay);
          break;
        case RecurrenceType.none:
          return instances;
      }
    }
    
    return instances;
  }
}
