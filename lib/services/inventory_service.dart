import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_supabase_service.dart';
import '../models/inventory_item.dart';
import '../models/inventory_addition.dart';
import '../models/inventory_consumption.dart';

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
    Future<InventoryItem?> _attemptInsert(Map<String, dynamic> data) async {
      final res =
          await client.from('inventory_items').insert(data).select().single();
      return InventoryItem.fromMap(res);
    }

    try {
      return await _attemptInsert({...base});
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        lastError = 'RLS blocked insert. Add inventory_items insert policy.';
        return null;
      }
      if (msg.contains('created_at') || msg.contains('updated_at')) {
        final retry =
            {...base}
              ..remove('created_at')
              ..remove('updated_at');
        try {
          return await _attemptInsert(retry);
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
        final trimmed =
            item.toMap()
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

  // ============================================================
  // INVENTORY ADDITIONS - Track when materials are added
  // ============================================================

  /// Create a new inventory addition record
  Future<InventoryAddition?> createAddition(InventoryAddition addition) async {
    lastError = null;
    try {
      final data = addition.toMap()..remove('id');
      final res =
          await client
              .from('inventory_additions')
              .insert(data)
              .select()
              .single();
      return InventoryAddition.fromMap(res);
    } on PostgrestException catch (e) {
      lastError = e.message;
      return null;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return null;
    }
  }

  /// Fetch all inventory additions, optionally filtered by item
  Future<List<InventoryAddition>> fetchAdditions({int? inventoryItemId}) async {
    try {
      var query = client
          .from('inventory_additions')
          .select()
          .order('addition_date', ascending: false)
          .order('created_at', ascending: false);

      if (inventoryItemId != null) {
        query = client
            .from('inventory_additions')
            .select()
            .eq('inventory_item_id', inventoryItemId)
            .order('addition_date', ascending: false)
            .order('created_at', ascending: false);
      }

      final response = await query;
      return (response as List)
          .map((e) => InventoryAddition.fromMap(e))
          .toList();
    } catch (e) {
      lastError = 'Fetch additions failed: $e';
      return [];
    }
  }

  /// Delete an inventory addition record
  Future<bool> deleteAddition(int id) async {
    try {
      await client.from('inventory_additions').delete().eq('id', id);
      return true;
    } catch (e) {
      lastError = 'Delete addition failed: $e';
      return false;
    }
  }

  // ============================================================
  // INVENTORY CONSUMPTIONS - Track when materials are consumed
  // ============================================================

  /// Create a new inventory consumption record
  Future<InventoryConsumption?> createConsumption(
    InventoryConsumption consumption,
  ) async {
    lastError = null;
    try {
      final data = consumption.toMap()..remove('id');
      final res =
          await client
              .from('inventory_consumptions')
              .insert(data)
              .select()
              .single();
      return InventoryConsumption.fromMap(res);
    } on PostgrestException catch (e) {
      lastError = e.message;
      return null;
    } catch (e) {
      lastError = 'Unexpected: $e';
      return null;
    }
  }

  /// Fetch all inventory consumptions, optionally filtered by item
  Future<List<InventoryConsumption>> fetchConsumptions({
    int? inventoryItemId,
  }) async {
    try {
      var query = client
          .from('inventory_consumptions')
          .select()
          .order('consumption_date', ascending: false)
          .order('created_at', ascending: false);

      if (inventoryItemId != null) {
        query = client
            .from('inventory_consumptions')
            .select()
            .eq('inventory_item_id', inventoryItemId)
            .order('consumption_date', ascending: false)
            .order('created_at', ascending: false);
      }

      final response = await query;
      return (response as List)
          .map((e) => InventoryConsumption.fromMap(e))
          .toList();
    } catch (e) {
      lastError = 'Fetch consumptions failed: $e';
      return [];
    }
  }

  /// Delete an inventory consumption record
  Future<bool> deleteConsumption(int id) async {
    try {
      await client.from('inventory_consumptions').delete().eq('id', id);
      return true;
    } catch (e) {
      lastError = 'Delete consumption failed: $e';
      return false;
    }
  }

  // ============================================================
  // COMBINED OPERATIONS - Add/Consume with history tracking
  // ============================================================

  /// Add quantity to inventory and create an addition record
  Future<bool> addQuantityWithHistory({
    required InventoryItem item,
    required double quantity,
    required DateTime additionDate,
    String? supplier,
    String? notes,
    String? addedBy,
  }) async {
    if (item.id == null) return false;

    // First, update the inventory item quantity
    final updatedItem = InventoryItem(
      id: item.id,
      name: item.name,
      type: item.type,
      quantity: item.quantity + quantity,
      minQuantity: item.minQuantity,
      category: item.category,
    );

    final updated = await update(updatedItem);
    if (!updated) return false;

    // Then, create the addition record
    final addition = InventoryAddition(
      inventoryItemId: item.id!,
      itemName: item.name,
      quantity: quantity,
      additionDate: additionDate,
      supplier: supplier,
      notes: notes,
      addedBy: addedBy,
    );

    final result = await createAddition(addition);
    return result != null;
  }

  /// Consume quantity from inventory and create a consumption record
  Future<bool> consumeQuantityWithHistory({
    required InventoryItem item,
    required double quantity,
    required DateTime consumptionDate,
    String? purpose,
    String? batchNo,
    String? notes,
    String? consumedBy,
  }) async {
    if (item.id == null) return false;
    if (quantity > item.quantity) {
      lastError = 'Cannot consume more than available quantity';
      return false;
    }

    // First, update the inventory item quantity
    final updatedItem = InventoryItem(
      id: item.id,
      name: item.name,
      type: item.type,
      quantity: item.quantity - quantity,
      minQuantity: item.minQuantity,
      category: item.category,
    );

    final updated = await update(updatedItem);
    if (!updated) return false;

    // Then, create the consumption record
    final consumption = InventoryConsumption(
      inventoryItemId: item.id!,
      itemName: item.name,
      quantity: quantity,
      consumptionDate: consumptionDate,
      purpose: purpose,
      batchNo: batchNo,
      notes: notes,
      consumedBy: consumedBy,
    );

    final result = await createConsumption(consumption);
    return result != null;
  }
}
