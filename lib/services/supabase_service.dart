import '../models/order_item.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../models/calendar_task.dart';
import '../models/alert.dart';

class SupabaseService {
  // Add an order item to the database (stub)
  Future<void> addOrderItem(OrderItem item) async {
    await client.from('order_items').insert(item.toMap());
  }

  // Get all order items for a given order (stub)
  Future<List<OrderItem>> getOrderItemsForOrder(int orderId) async {
    final response = await client
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    return (response as List).map((item) => OrderItem.fromMap(item)).toList();
  }

  // Update an existing order item
  Future<bool> updateOrderItem(OrderItem item) async {
    if (item.id == null) return false;
    final data = item.toMap()..remove('id');
    try {
      await client.from('order_items').update(data).eq('id', item.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating order_item ${item.id}: $e');
      return false;
    }
  }

  // Delete an order item by id
  Future<bool> deleteOrderItem(int itemId) async {
    try {
      await client.from('order_items').delete().eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error deleting order_item $itemId: $e');
      return false;
    }
  }

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Holds last human‑readable inventory error message (e.g. RLS guidance)
  String? lastInventoryError;
  String? lastCalendarError;
  String? lastAlertError;

  // Customer operations (Deprecated: use CustomersService)
  Future<List<Customer>> getCustomers() async {
    try {
      final response = await client
          .from('customers')
          .select()
          .order('company_name'); // Use correct column name

      return (response as List).map((item) => Customer.fromMap(item)).toList();
    } catch (e) {
      debugPrint('Error fetching customers: $e');
      return [];
    }
  }

  Future<Customer?> addCustomer(Customer customer) async {
    // First attempt payload
    final baseData = customer.toMap()..remove('id');
    // Some columns may not exist yet in DB (e.g. is_active) – remove dynamically on retry
    Future<Customer?> tryInsert(Map<String, dynamic> data) async {
      final response =
          await client.from('customers').insert(data).select().single();
      return Customer.fromMap(response);
    }

    try {
      return await tryInsert({...baseData});
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains("is_active") || e.code == 'PGRST204') {
        // Remove is_active and retry
        final retryData = {...baseData}..remove('is_active');
        try {
          return await tryInsert(retryData);
        } catch (e2) {
          debugPrint('Retry addCustomer without is_active failed: $e2');
          return null;
        }
      }
      debugPrint('PostgrestException addCustomer: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected error addCustomer: $e');
      return null;
    }
  }

  Future<bool> updateCustomer(Customer customer) async {
    try {
      await client
          .from('customers')
          .update(customer.toMap())
          .eq('id', customer.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating customer: $e');
      return false;
    }
  }

  Future<bool> deleteCustomer(int customerId) async {
    try {
      await client.from('customers').delete().eq('id', customerId);
      return true;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }

  // Order operations (remains here; can be extracted similarly if desired)
  Future<List<Order>> getOrders() async {
    // Prefer simple select first to avoid dependency on FK/relationships in PostgREST cache
    // If created_at doesn't exist in older schemas, fall back to ordering by id
    try {
      final response = await client
          .from('orders')
          .select('*')
          .order('created_at', ascending: false);
      return (response as List).map((item) => Order.fromMap(item)).toList();
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      // Fallback if created_at column is missing or similar ordering issue
      if (msg.contains('column') && msg.contains('created_at')) {
        try {
          final res = await client.from('orders').select('*').order('id');
          return (res as List).map((m) => Order.fromMap(m)).toList();
        } catch (_) {}
      }
      // Legacy: if someone reintroduces relationship select and it fails, try plain select
      if (e.code == 'PGRST200' ||
          msg.contains('relationship') ||
          msg.contains('schema cache')) {
        try {
          final res = await client.from('orders').select('*').order('id');
          return (res as List).map((m) => Order.fromMap(m)).toList();
        } catch (_) {}
      }
      debugPrint('Error fetching orders: $e');
      return [];
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return [];
    }
  }

  Future<Order?> addOrder(Order order) async {
    final baseData = order.toMap()
      ..remove('id')
      ..remove('location');

    Future<Order?> tryInsert(Map<String, dynamic> data) async {
      final response =
          await client.from('orders').insert(data).select().single();
      return Order.fromMap(response);
    }

    try {
      return await tryInsert({...baseData});
    } on PostgrestException catch (e) {
      final msg = e.message;
      // Handle check constraint on order_status
      if (e.code == '23514' || msg.contains('order_status')) {
        // Try a safe fallback sequence for order_status
        const fallbacks = ['pending', 'processing', 'open', 'created'];
        for (final candidate in fallbacks) {
          if (baseData['order_status'] == candidate) continue;
          try {
            final alt = {...baseData, 'order_status': candidate};
            final inserted = await tryInsert(alt);
            if (inserted != null) return inserted;
          } catch (_) {
            /* continue */
          }
        }
        // Last resort: remove the field entirely and let default apply
        try {
          final without = {...baseData}..remove('order_status');
          return await tryInsert(without);
        } catch (e2) {
          debugPrint('Retry addOrder without order_status failed: $e2');
          return null;
        }
      }
      debugPrint('PostgrestException addOrder: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected error addOrder: $e');
      return null;
    }
  }

  Future<bool> updateOrder(Order order) async {
    try {
      final data = order.toMap()
        ..remove('location'); // location is not a column in orders
      await client.from('orders').update(data).eq('id', order.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating order: $e');
      return false;
    }
  }

  Future<bool> deleteOrder(int orderId) async {
    try {
      await client.from('orders').delete().eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error deleting order: $e');
      return false;
    }
  }

  // Inventory operations (Deprecated: use InventoryService)
  Future<List<InventoryItem>> getInventoryItems() async {
    try {
      final response = await client
          .from('inventory_items')
          .select()
          .order('name');

      return (response as List)
          .map((item) => InventoryItem.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error fetching inventory items: $e');
      return [];
    }
  }

  Future<InventoryItem?> addInventoryItem(InventoryItem item) async {
    Map<String, dynamic> base = item.toMap();
    base.remove('id');

    // Ensure the `category` field is valid before inserting.
    if (![
      'Raw Materials',
      'Finished Goods',
      'Additives',
      'Spare Parts',
    ].contains(item.category)) {
      lastInventoryError = 'Invalid category: ${item.category}';
      debugPrint('Invalid category: ${item.category}');
      return null;
    }

    // Build payload mapping only the app's field names.
    final Map<String, dynamic> payload = Map<String, dynamic>.from(base);

    // quantity in the model is a double; DB accepts numeric(10,3).
    payload['quantity'] = item.quantity;

    // min quantity mapping (nullable)
    if (item.minQuantity != null) {
      payload['min_quantity'] = item.minQuantity;
    } else {
      payload.remove('min_quantity');
    }

    // Ensure timestamps only included if present in base map (to avoid unexpected column errors)
    if (!payload.containsKey('created_at')) payload.remove('created_at');
    if (!payload.containsKey('updated_at')) payload.remove('updated_at');

    Future<InventoryItem?> tryInsert(Map<String, dynamic> data) async {
      final response =
          await client.from('inventory_items').insert(data).select().single();
      return InventoryItem.fromMap(response);
    }

    try {
      lastInventoryError = null;
      return await tryInsert(payload);
    } on PostgrestException catch (e) {
      final rawMsg = e.message;
      final msg = rawMsg.toLowerCase();
      // RLS violation detection
      if (msg.contains('row-level security') || msg.contains('rls')) {
        lastInventoryError =
            'Row Level Security blocked the insert. Create a policy for inserts on inventory_items (see console logs).';
        debugPrint(
          '[RLS] inventory_items insert blocked. You need a policy, e.g.:\n'
          'CREATE POLICY "inventory_items_insert" ON public.inventory_items FOR INSERT WITH CHECK (auth.role() = \'authenticated\');',
        );
        return null;
      }
      // Missing timestamp columns – retry
      if (msg.contains('created_at') || msg.contains('updated_at')) {
        final retry =
            {...base}
              ..remove('created_at')
              ..remove('updated_at');
        try {
          return await tryInsert(retry);
        } catch (e2) {
          lastInventoryError = 'Failed retry without timestamps: $e2';
          debugPrint('Retry addInventoryItem without timestamps failed: $e2');
          return null;
        }
      }
      lastInventoryError = rawMsg;
      debugPrint('PostgrestException addInventoryItem: $rawMsg');
      return null;
    } catch (e) {
      lastInventoryError = 'Unexpected error: $e';
      debugPrint('Unexpected error addInventoryItem: $e');
      return null;
    }
  }

  Future<bool> updateInventoryItem(InventoryItem item) async {
    Map<String, dynamic> data = item.toMap();

    // Map only canonical column names for update.
    final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
    payload.remove('id');

    // quantity mapping (model defines quantity as non-nullable)
    payload['quantity'] = item.quantity;

    // min quantity mapping
    if (item.minQuantity != null) {
      payload['min_quantity'] = item.minQuantity;
    }

    try {
      await client.from('inventory_items').update(payload).eq('id', item.id!);
      return true;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('created_at') || msg.contains('updated_at')) {
        final trimmed =
            {...payload}
              ..remove('created_at')
              ..remove('updated_at');
        try {
          await client
              .from('inventory_items')
              .update(trimmed)
              .eq('id', item.id!);
          return true;
        } catch (e2) {
          debugPrint(
            'Retry updateInventoryItem without timestamps failed: $e2',
          );
          return false;
        }
      }
      debugPrint('PostgrestException updateInventoryItem: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      return false;
    }
  }

  Future<bool> deleteInventoryItem(int itemId) async {
    try {
      await client.from('inventory_items').delete().eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      return false;
    }
  }

  // Calendar task operations (Deprecated: use CalendarTasksService)
  Future<List<CalendarTask>> getCalendarTasks() async {
    try {
      final response = await client
          .from('calendar_tasks')
          .select()
          .order('task_date'); // correct column name

      return (response as List)
          .map((item) => CalendarTask.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error fetching calendar tasks: $e');
      return [];
    }
  }

  Future<CalendarTask?> addCalendarTask(CalendarTask task) async {
    final base = task.toMap()..remove('id');
    Future<CalendarTask?> attemptInsert(Map<String, dynamic> data) async {
      final response =
          await client.from('calendar_tasks').insert(data).select().single();
      return CalendarTask.fromMap(response);
    }

    try {
      lastCalendarError = null;
      return await attemptInsert({...base});
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        lastCalendarError =
            'RLS blocked calendar task insert. Create insert/select policies on calendar_tasks.';
        debugPrint(
          '[RLS] calendar_tasks insert blocked. Example policy:\n'
          'CREATE POLICY "calendar_tasks_insert" ON public.calendar_tasks FOR INSERT WITH CHECK (auth.role() = \'authenticated\');',
        );
        return null;
      }
      if (msg.contains('task_date')) {
        // If schema uses date instead of task_date, retry with renamed key
        if (base.containsKey('task_date')) {
          final retry = {...base};
          retry['date'] = retry.remove('task_date');
          try {
            return await attemptInsert(retry);
          } catch (_) {}
        }
      }
      lastCalendarError = e.message;
      debugPrint('PostgrestException addCalendarTask: ${e.message}');
      return null;
    } catch (e) {
      lastCalendarError = 'Unexpected: $e';
      debugPrint('Error adding calendar task: $e');
      return null;
    }
  }

  Future<bool> updateCalendarTask(CalendarTask task) async {
    try {
      await client
          .from('calendar_tasks')
          .update(task.toMap())
          .eq('id', task.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating calendar task: $e');
      return false;
    }
  }

  Future<bool> deleteCalendarTask(int taskId) async {
    try {
      await client.from('calendar_tasks').delete().eq('id', taskId);
      return true;
    } catch (e) {
      debugPrint('Error deleting calendar task: $e');
      return false;
    }
  }

  // Alert operations (Deprecated: use AlertsService)
  Future<List<Alert>> getAlerts() async {
    try {
      final response = await client
          .from('alerts')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((m) => Alert.fromMap(m)).toList();
    } on PostgrestException catch (e) {
      lastAlertError = e.message;
      return [];
    } catch (e) {
      lastAlertError = 'Unexpected: $e';
      return [];
    }
  }

  Future<Alert?> addAlert(Alert alert) async {
    lastAlertError = null;
    final base = alert.toMap()..remove('id');
    Future<Alert?> attemptInsert(Map<String, dynamic> data) async {
      final res = await client.from('alerts').insert(data).select().single();
      return Alert.fromMap(res);
    }

    try {
      return await attemptInsert({...base});
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        lastAlertError =
            'RLS blocked alert insert. Add insert/select policies.';
        debugPrint(
          '[RLS] alerts insert blocked. Example policy:\n'
          'CREATE POLICY "alerts_insert" ON public.alerts FOR INSERT WITH CHECK (auth.role() = \'authenticated\');',
        );
        return null;
      }
      if (msg.contains('description')) {
        final retry = {...base};
        retry['message'] = retry.remove('description');
        try {
          return await attemptInsert(retry);
        } catch (_) {}
      }
      lastAlertError = e.message;
      debugPrint('PostgrestException addAlert: ${e.message}');
      return null;
    } catch (e) {
      lastAlertError = 'Unexpected: $e';
      debugPrint('Unexpected error addAlert: $e');
      return null;
    }
  }

  Future<bool> updateAlert(Alert alert) async {
    if (alert.id == null) return false;
    try {
      await client.from('alerts').update(alert.toMap()).eq('id', alert.id!);
      return true;
    } on PostgrestException catch (e) {
      lastAlertError = e.message;
      return false;
    } catch (e) {
      lastAlertError = 'Unexpected: $e';
      return false;
    }
  }

  Future<bool> markAlertRead(int id, {bool isRead = true}) async {
    try {
      await client.from('alerts').update({'is_read': isRead}).eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      lastAlertError = e.message;
      return false;
    } catch (e) {
      lastAlertError = 'Unexpected: $e';
      return false;
    }
  }

  Future<bool> deleteAlert(int id) async {
    try {
      await client.from('alerts').delete().eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      lastAlertError = e.message;
      return false;
    } catch (e) {
      lastAlertError = 'Unexpected: $e';
      return false;
    }
  }

  // Production Batch operations
  Future<List<Map<String, dynamic>>> getProductionBatches() async {
    try {
      // Only return batches that are currently queued / part of the active queue.
      // We consider a batch 'in the queue' when `queued_at` IS NOT NULL and
      // `moved_to_inventory` is false. This keeps historical/completed batches
      // in `production_batches` but excludes them from the active queue view.
      // Include the related order's order_status so we can exclude batches
      // whose parent order has been dispatched or is pending approval.
      final response = await client
          .from('production_batches')
          .select('*, orders(order_status)')
          .filter('queued_at', 'not.is', 'null')
          .eq('moved_to_inventory', false)
          .order('queued_at', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();

      // Remove any batches whose linked order has order_status = 'dispatched', 'shipped' OR 'pending_approval'
      final filtered =
          rows.where((batch) {
            try {
              final orderRel = batch['orders'];
              // If it's a standalone batch (order_id null), we show it.
              if (orderRel == null) return true;
              
              final orderStatus =
                  (orderRel['order_status'] ?? '').toString().toLowerCase();
              
              // Filter out completed/shipped AND pending approval orders
              if (orderStatus == 'dispatched' || 
                  orderStatus == 'shipped' ||
                  orderStatus == 'pending_approval') {
                return false;
              }
            } catch (_) {
              // If unexpected structure, keep the batch to avoid hiding items unintentionally
              return true;
            }
            return true;
          }).toList();

      return filtered.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching production batches: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> addProductionBatch(
    Map<String, dynamic> batch,
  ) async {
    try {
      // Ensure we're authenticated
      if (!isAuthenticated) {
        await signInAnonymously();
      }

      final data = {...batch};
      data.remove('id'); // Remove id, let database generate it

      // Ensure required fields for existing schema
      if (!data.containsKey('batch_no')) {
        data['batch_no'] = 'BATCH-${DateTime.now().millisecondsSinceEpoch}';
      }
      if (!data.containsKey('status')) {
        data['status'] = 'in_production';
      }

      // Get current user ID if available
      final currentUser = client.auth.currentUser;
      if (currentUser != null && !data.containsKey('created_by')) {
        data['created_by'] = currentUser.id;
      }

      // order_id can be null for standalone queue batches - explicitly set if not provided
      if (!data.containsKey('order_id')) {
        data['order_id'] = null;
      }

      final response =
          await client
              .from('production_batches')
              .insert(data)
              .select()
              .single();

      return response;
    } catch (e) {
      debugPrint('Error adding production batch: $e');
      return null;
    }
  }

  Future<bool> updateProductionBatch(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final data = {...updates};

      // NOTE: Some installations of the database schema do not have an
      // `updated_at` column on `production_batches`. Avoid adding the
      // column automatically here so PostgREST doesn't error when the
      // column is missing. If your schema does have `updated_at`, you can
      // add it explicitly in the updates map from the caller.
      await client.from('production_batches').update(data).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('Error updating production batch: $e');
      return false;
    }
  }

  Future<bool> updateProductionBatchStatus(
    String id,
    String status, {
    double? progress,
  }) async {
    try {
      final data = <String, dynamic>{};

      // Map app status to database status
      if (status == 'completed') {
        data['status'] = 'ready';
        data['ready_at'] = DateTime.now().toIso8601String();
      } else if (status == 'in_progress') {
        data['status'] = 'in_production';
        if (!data.containsKey('started_at')) {
          data['started_at'] = DateTime.now().toIso8601String();
        }
      } else if (status == 'queued' || status == 'paused') {
        data['status'] = 'in_production'; // Keep as in_production in DB
      }

      if (progress != null) {
        data['progress'] = progress;
      }

      await client.from('production_batches').update(data).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('Error updating production batch status: $e');
      return false;
    }
  }

  Future<bool> deleteProductionBatch(String id) async {
    try {
      await client.from('production_batches').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting production batch: $e');
      return false;
    }
  }

  Future<bool> deleteProductionQueueItem(String id) async {
    try {
      await client.from('production_queue').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting production queue item: $e');
      return false;
    }
  }

  /// Call server-side function `ship_order_and_batches(order_id, status, shipped_at)`
  /// if you've created that RPC. This function attempts to update the order and
  /// associated batches in one atomic call on the server.
  Future<bool> shipOrderAndBatchesRpc(
    int orderId, {
    String status = 'dispatched',
    DateTime? shippedAt,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_order_id': orderId,
        'p_status': status,
      };
      if (shippedAt != null) {
        params['p_shipped_at'] = shippedAt.toIso8601String();
      }
      // Call RPC - using select() to trigger execution and ignore returned rows.
      await client.rpc('ship_order_and_batches', params: params).select();
      return true;
    } catch (e) {
      debugPrint('RPC ship_order_and_batches failed: $e');
      return false;
    }
  }

  /// Archive a production batch into `production_queue_history` then remove
  /// it from `production_batches` so it's no longer in the active queue.
  Future<bool> archiveBatchAndRemoveFromQueue(
    int batchId,
    Map<String, dynamic> info,
  ) async {
    try {
      // Fetch the batch row
      final batchRes =
          await client
              .from('production_batches')
              .select()
              .eq('id', batchId)
              .maybeSingle();

      if (batchRes == null) {
        debugPrint('archiveBatch: batch not found: $batchId');
        return false;
      }

      // Update the production_batches row to mark as shipped/removed from the queue.
      final updates = <String, dynamic>{
        'queued_at': null,
        'position': null,
        // Set status to the provided one or 'shipped' to indicate it's no longer active
        'status': info['status'] ?? 'shipped',
        'progress': info['progress'] ?? 100,
      };

      await client.from('production_batches').update(updates).eq('id', batchId);

      return true;
    } catch (e) {
      debugPrint('archiveBatchAndRemoveFromQueue error: $e');
      return false;
    }
  }

  Future<bool> updateBatchQueuePosition(String id, int queuePosition) async {
    try {
      await client
          .from('production_batches')
          .update({'queue_position': queuePosition})
          .eq('id', id);

      return true;
    } catch (e) {
      debugPrint('Error updating batch queue position: $e');
      return false;
    }
  }

  // Authentication helpers
  Future<bool> signInAnonymously() async {
    try {
      // Some versions of the gotrue client removed the strongly-typed
      // signInAnonymously method. Use a dynamic call to remain
      // compatible across versions.
      final auth = client.auth;
      try {
        await (auth as dynamic).signInAnonymously();
      } catch (_) {
        // If anonymous sign-in isn't supported, attempt a no-op or
        // fallback to currentUser check. Return true if already signed in.
        if (client.auth.currentUser != null) return true;
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  bool get isAuthenticated => client.auth.currentUser != null;
}
