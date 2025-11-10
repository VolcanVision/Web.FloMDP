import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lab_test.dart';
import '../models/sub_test.dart';

class LabTestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all active tests
  Future<List<LabTest>> getActiveTests() async {
    try {
      final response = await _supabase
          .from('lab_tests')
          .select()
          .eq('status', 'active')
          .order('test_date', ascending: false);

      return (response as List).map((item) => LabTest.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching active tests: $e');
      rethrow;
    }
  }

  // Get all completed tests
  Future<List<LabTest>> getCompletedTests() async {
    try {
      final response = await _supabase
          .from('lab_tests')
          .select()
          .eq('status', 'completed')
          .order('completed_at', ascending: false);

      return (response as List).map((item) => LabTest.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching completed tests: $e');
      rethrow;
    }
  }

  // Get test counts
  Future<Map<String, int>> getTestCounts() async {
    try {
      final activeTests = await _supabase
          .from('lab_tests')
          .select()
          .eq('status', 'active');

      final completedTests = await _supabase
          .from('lab_tests')
          .select()
          .eq('status', 'completed');

      return {
        'active': (activeTests as List).length,
        'completed': (completedTests as List).length,
      };
    } catch (e) {
      print('Error fetching test counts: $e');
      return {'active': 0, 'completed': 0};
    }
  }

  // Get test by ID
  Future<LabTest?> getTestById(int id) async {
    try {
      final response = await _supabase
          .from('lab_tests')
          .select()
          .eq('id', id)
          .single();

      return LabTest.fromMap(response);
    } catch (e) {
      print('Error fetching test by ID: $e');
      return null;
    }
  }

  // Create new test
  Future<LabTest?> createTest(LabTest test) async {
    try {
      final response = await _supabase
          .from('lab_tests')
          .insert(test.toMap(includeId: false))
          .select()
          .single();

      return LabTest.fromMap(response);
    } catch (e) {
      print('Error creating test: $e');
      rethrow;
    }
  }

  // Update test
  Future<LabTest?> updateTest(LabTest test) async {
    try {
      final response = await _supabase
          .from('lab_tests')
          .update(test.toMap())
          .eq('id', test.id!)
          .select()
          .single();

      return LabTest.fromMap(response);
    } catch (e) {
      print('Error updating test: $e');
      rethrow;
    }
  }

  // Update composition
  Future<void> updateComposition(int testId, String composition) async {
    try {
      await _supabase
          .from('lab_tests')
          .update({'composition': composition})
          .eq('id', testId);
    } catch (e) {
      print('Error updating composition: $e');
      rethrow;
    }
  }

  // Mark test as completed
  Future<void> markAsCompleted(int testId) async {
    try {
      await _supabase
          .from('lab_tests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', testId);
    } catch (e) {
      print('Error marking test as completed: $e');
      rethrow;
    }
  }

  // Mark test as pending (keeps it active)
  Future<void> markAsPending(int testId) async {
    try {
      await _supabase
          .from('lab_tests')
          .update({'status': 'active', 'completed_at': null})
          .eq('id', testId);
    } catch (e) {
      print('Error marking test as pending: $e');
      rethrow;
    }
  }

  // Delete test
  Future<void> deleteTest(int testId) async {
    try {
      await _supabase.from('lab_tests').delete().eq('id', testId);
    } catch (e) {
      print('Error deleting test: $e');
      rethrow;
    }
  }

  // ========== SUB-TESTS METHODS ==========

  // Get all sub-tests for a lab test
  Future<List<SubTest>> getSubTests(int labTestId) async {
    try {
      final response = await _supabase
          .from('sub_tests')
          .select()
          .eq('lab_test_id', labTestId)
          .order('test_date', ascending: true);

      return (response as List).map((item) => SubTest.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching sub-tests: $e');
      rethrow;
    }
  }

  // Create a new sub-test
  Future<SubTest> createSubTest(SubTest subTest) async {
    try {
      final response = await _supabase
          .from('sub_tests')
          .insert(subTest.toMap(includeId: false))
          .select()
          .single();

      return SubTest.fromMap(response);
    } catch (e) {
      print('Error creating sub-test: $e');
      rethrow;
    }
  }

  // Update a sub-test
  Future<void> updateSubTest(SubTest subTest) async {
    try {
      await _supabase
          .from('sub_tests')
          .update(subTest.toMap(includeId: false))
          .eq('id', subTest.id!);
    } catch (e) {
      print('Error updating sub-test: $e');
      rethrow;
    }
  }

  // Delete a sub-test
  Future<void> deleteSubTest(int subTestId) async {
    try {
      await _supabase.from('sub_tests').delete().eq('id', subTestId);
    } catch (e) {
      print('Error deleting sub-test: $e');
      rethrow;
    }
  }
}
