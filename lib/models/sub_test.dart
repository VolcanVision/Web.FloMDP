class SubTest {
  int? id;
  int labTestId;
  String testName;
  DateTime? testDate;
  String? result;
  String? notes;
  DateTime? createdAt;
  DateTime? updatedAt;

  SubTest({
    this.id,
    required this.labTestId,
    required this.testName,
    this.testDate,
    this.result,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'lab_test_id': labTestId,
      'test_name': testName,
      'test_date': testDate?.toIso8601String().split('T')[0],
      'result': result,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    if (includeId && id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory SubTest.fromMap(Map<String, dynamic> map) {
    return SubTest(
      id: map['id'],
      labTestId: map['lab_test_id'],
      testName: map['test_name'] ?? '',
      testDate: map['test_date'] != null
          ? DateTime.parse(map['test_date'])
          : null,
      result: map['result'],
      notes: map['notes'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  SubTest copyWith({
    int? id,
    int? labTestId,
    String? testName,
    DateTime? testDate,
    String? result,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubTest(
      id: id ?? this.id,
      labTestId: labTestId ?? this.labTestId,
      testName: testName ?? this.testName,
      testDate: testDate ?? this.testDate,
      result: result ?? this.result,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
