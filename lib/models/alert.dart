class Alert {
  int? id;
  String title;
  String description; // maps to description or message column
  String alertType; // info | warning | error | success
  bool isRead;
  int? targetUserId;
  int? relatedOrderId;
  DateTime? createdAt;

  Alert({
    this.id,
    required this.title,
    required this.description,
    this.alertType = 'info',
    this.isRead = false,
    this.targetUserId,
    this.relatedOrderId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      // Prefer description; duplicate to message if backend only has message
      'description': description,
      'alert_type': alertType,
      'is_read': isRead ? 1 : 0,
      'target_user_id': targetUserId,
      'related_order_id': relatedOrderId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? map['message'] ?? '',
      alertType: map['alert_type'] ?? 'info',
      isRead: (map['is_read'] == 1) || (map['is_read'] == true),
      targetUserId: map['target_user_id'],
      relatedOrderId: map['related_order_id'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
    );
  }
}
