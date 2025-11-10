class LabTest {
  int? id;
  String testName;
  String? materialName;
  String? composition;
  String? result;
  bool? passed;
  String? notes;
  DateTime? testedAt;
  DateTime? testDate;
  String status; // 'active', 'completed', 'pending'
  DateTime? createdAt;
  DateTime? completedAt;

  LabTest({
    this.id,
    required this.testName,
    this.materialName,
    this.composition,
    this.result,
    this.passed,
    this.notes,
    this.testedAt,
    this.testDate,
    this.status = 'active',
    this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = <String, dynamic>{
      'test_name': testName,
      'material_name': materialName,
      'composition': composition,
      'result': result,
      'passed': passed,
      'notes': notes,
      'tested_at': testedAt?.toIso8601String(),
      'test_date': testDate?.toIso8601String().split('T')[0],
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };

    if (includeId && id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory LabTest.fromMap(Map<String, dynamic> map) {
    return LabTest(
      id: map['id'],
      testName: map['test_name'] ?? '',
      materialName: map['material_name'],
      composition: map['composition'],
      result: map['result'],
      passed: map['passed'],
      notes: map['notes'],
      testedAt: map['tested_at'] != null
          ? DateTime.parse(map['tested_at'])
          : null,
      testDate: map['test_date'] != null
          ? DateTime.parse(map['test_date'])
          : null,
      status: map['status'] ?? 'active',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'])
          : null,
    );
  }

  LabTest copyWith({
    int? id,
    String? testName,
    String? materialName,
    String? composition,
    String? result,
    bool? passed,
    String? notes,
    DateTime? testedAt,
    DateTime? testDate,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return LabTest(
      id: id ?? this.id,
      testName: testName ?? this.testName,
      materialName: materialName ?? this.materialName,
      composition: composition ?? this.composition,
      result: result ?? this.result,
      passed: passed ?? this.passed,
      notes: notes ?? this.notes,
      testedAt: testedAt ?? this.testedAt,
      testDate: testDate ?? this.testDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class TestDateResult {
  DateTime date;
  String result;
  bool isPending;

  TestDateResult({
    required this.date,
    required this.result,
    this.isPending = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'result': result,
      'isPending': isPending,
    };
  }

  factory TestDateResult.fromMap(Map<String, dynamic> map) {
    return TestDateResult(
      date: DateTime.parse(map['date']),
      result: map['result'] ?? '',
      isPending: map['isPending'] ?? false,
    );
  }
}
