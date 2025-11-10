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
    final base = task.toMap()
      ..remove('id')
      ..remove('created_at') // Let database set this with DEFAULT NOW()
      ..remove('updated_at'); // Let database set this with DEFAULT NOW()

    // Set created_by and assigned_by to current user if not already set
    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      base['assigned_by'] ??= currentUser.id;
      // Note: created_by might be an integer user ID in your schema
      // If it's UUID, uncomment the next line:
      // base['created_by'] ??= currentUser.id;
    }

    Future<CalendarTask?> _try(Map<String, dynamic> data) async {
      final res = await client
          .from('calendar_tasks')
          .insert(data)
          .select()
          .single();
      return CalendarTask.fromMap(res);
    }

    try {
      return await _try({...base});
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
            return await _try(retry);
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
    if (task.id == null) return false;
    try {
      await client
          .from('calendar_tasks')
          .update(task.toMap())
          .eq('id', task.id!);
      return true;
    } catch (e) {
      lastError = 'Update failed: $e';
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
}
