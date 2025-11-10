import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_supabase_service.dart';
import '../models/inventory_item.dart';

/// Inventory specific data access & logic.
class InventoryService extends BaseSupabaseService {
  String? lastError;

  Future<List<InventoryItem>> fetchAll() async {
    try {
      final response = await client
          .from('inventory_items')
          .select()
          .order('name');
      return (response as List).map((e) => InventoryItem.fromMap(e)).toList();
    } catch (e) {
      lastError = 'Fetch failed: $e';
      return [];
    }
  }

  Future<InventoryItem?> create(InventoryItem item) async {
    lastError = null;
    final base = item.toMap()..remove('id');
    Future<InventoryItem?> _try(Map<String, dynamic> data) async {
      final res = await client
          .from('inventory_items')
          .insert(data)
          .select()
          .single();
      return InventoryItem.fromMap(res);
    }

    try {
      return await _try({...base});
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        lastError = 'RLS blocked insert. Add inventory_items insert policy.';
        return null;
      }
      if (msg.contains('created_at') || msg.contains('updated_at')) {
        final retry = {...base}
          ..remove('created_at')
          ..remove('updated_at');
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

  Future<bool> update(InventoryItem item) async {
    if (item.id == null) return false;
    try {
      await client
          .from('inventory_items')
          .update(item.toMap())
          .eq('id', item.id!);
      return true;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('created_at') || msg.contains('updated_at')) {
        final trimmed = item.toMap()
          ..remove('created_at')
          ..remove('updated_at');
        try {
          await client
              .from('inventory_items')
              .update(trimmed)
              .eq('id', item.id!);
          return true;
        } catch (_) {}
      }
      lastError = e.message;
      return false;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return false;
    }
  }

  Future<bool> remove(int id) async {
    try {
      await client.from('inventory_items').delete().eq('id', id);
      return true;
    } catch (e) {
      lastError = 'Delete failed: $e';
      return false;
    }
  }
}
