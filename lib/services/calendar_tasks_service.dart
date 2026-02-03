import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_supabase_service.dart';
import '../models/calendar_task.dart';

class CalendarTasksService extends BaseSupabaseService {
  String? lastError;

  Future<List<CalendarTask>> fetchAll() async {
    try {
      final res = await client
          .from('calendar_tasks')
          .select()
          .order('task_date');
      return (res as List).map((e) => CalendarTask.fromMap(e)).toList();
    } catch (e) {
      lastError = 'Fetch failed: $e';
      return [];
    }
  }

  Future<CalendarTask?> create(CalendarTask task) async {
    lastError = null;
    final base =
        task.toMap()
          ..remove('id')
          ..remove('created_at') // Let database set this with DEFAULT NOW()
          ..remove('updated_at'); // Let database set this with DEFAULT NOW()

    print(
      '[CalendarTasksService] Task assignedBy before processing: ${task.assignedBy}',
    );
    print(
      '[CalendarTasksService] base assigned_by before processing: ${base['assigned_by']}',
    );

    // Set assigned_by to current user ID only if not already provided
    // The caller may pass the role name for assigned_by, so don't override if present
    final currentUser = client.auth.currentUser;
    if (currentUser != null &&
        (base['assigned_by'] == null || base['assigned_by'] == '')) {
      base['assigned_by'] = currentUser.id;
      print(
        '[CalendarTasksService] Overwriting assigned_by with user ID: ${currentUser.id}',
      );
    }

    print('[CalendarTasksService] Final base payload: $base');

    Future<CalendarTask?> _attemptInsert(Map<String, dynamic> data) async {
      final res =
          await client.from('calendar_tasks').insert(data).select().single();
      return CalendarTask.fromMap(res);
    }

    try {
      return await _attemptInsert({...base});
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        lastError = 'RLS blocked calendar task insert. Add policy.';
        return null;
      }
      if (msg.contains('task_date')) {
        if (base.containsKey('task_date')) {
          final retry = {...base};
          retry['date'] = retry.remove('task_date');
          try {
            return await _attemptInsert(retry);
          } catch (_) {}
        }
      }
      lastError = e.message;
      return null;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return null;
    }
  }

  Future<bool> update(CalendarTask task) async {
    if (task.id == null) {
      lastError = 'Cannot update task without ID';
      return false;
    }
    try {
      final updateData = task.toMap();
      updateData.remove('id'); // Don't include id in update payload
      updateData.remove('created_at'); // Don't update created_at
      updateData['updated_at'] = DateTime.now().toIso8601String();

      print(
        '[CalendarTasksService] Updating task ${task.id} with: $updateData',
      );

      await client.from('calendar_tasks').update(updateData).eq('id', task.id!);
      lastError = null;
      print('[CalendarTasksService] Update successful for task ${task.id}');
      return true;
    } catch (e) {
      lastError = 'Update failed: $e';
      print('[CalendarTasksService] Update FAILED: $e');
      return false;
    }
  }

  Future<bool> remove(int id) async {
    try {
      await client.from('calendar_tasks').delete().eq('id', id);
      return true;
    } catch (e) {
      lastError = 'Delete failed: $e';
      return false;
    }
  }

  Future<bool> clearCompleted() async {
    try {
      await client.from('calendar_tasks').delete().eq('is_completed', true);
      return true;
    } catch (e) {
      lastError = 'Clear completed failed: $e';
      return false;
    }
  }
}
