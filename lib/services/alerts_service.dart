import 'package:postgrest/postgrest.dart';
import 'base_supabase_service.dart';
import '../models/alert.dart';

class AlertsService extends BaseSupabaseService {
  String? lastError;

  Future<List<Alert>> fetchAll() async {
    try {
      final res = await client
          .from('alerts')
          .select()
          .order('created_at', ascending: false);
      return (res as List).map((e) => Alert.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      lastError = e.message;
      return [];
    } catch (e) {
      lastError = 'Unexpected: $e';
      return [];
    }
  }

  Future<Alert?> create(Alert alert) async {
    lastError = null;
    final base = alert.toMap()..remove('id');
    Future<Alert?> _try(Map<String, dynamic> data) async {
      final res = await client.from('alerts').insert(data).select().single();
      return Alert.fromMap(res);
    }

    try {
      return await _try({...base});
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        lastError = 'RLS blocked alert insert. Add policy on alerts.';
        return null;
      }
      if (msg.contains('description')) {
        final retry = {...base};
        retry['message'] = retry.remove('description');
        try {
          return await _try(retry);
        } catch (_) {}
      }
      lastError = e.message;
      return null;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return null;
    }
  }

  Future<bool> update(Alert alert) async {
    if (alert.id == null) return false;
    try {
      await client.from('alerts').update(alert.toMap()).eq('id', alert.id!);
      return true;
    } on PostgrestException catch (e) {
      lastError = e.message;
      return false;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return false;
    }
  }

  Future<bool> markRead(int id, {bool isRead = true}) async {
    try {
      await client.from('alerts').update({'is_read': isRead}).eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      lastError = e.message;
      return false;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return false;
    }
  }

  Future<bool> remove(int id) async {
    try {
      await client.from('alerts').delete().eq('id', id);
      return true;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return false;
    }
  }
}
