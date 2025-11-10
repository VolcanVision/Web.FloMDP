import 'base_supabase_service.dart';
import '../models/production_batch_order.dart';

class ProductionBatchOrderService extends BaseSupabaseService {
  String? lastError;

  Future<ProductionBatchOrder?> create(ProductionBatchOrder batch) async {
    lastError = null;
    try {
      final data =
          batch.toMap()
            ..remove('id')
            ..remove('created_at')
            ..remove('updated_at');

      final res =
          await client
              .from('production_batches')
              .insert(data)
              .select()
              .single();

      return ProductionBatchOrder.fromMap(res);
    } catch (e) {
      lastError = 'Failed to create batch: $e';
      return null;
    }
  }

  Future<ProductionBatchOrder?> getByOrderId(int orderId) async {
    try {
      final res =
          await client
              .from('production_batches')
              .select()
              .eq('order_id', orderId)
              .maybeSingle();

      if (res == null) return null;
      return ProductionBatchOrder.fromMap(res);
    } catch (e) {
      lastError = 'Failed to fetch batch: $e';
      return null;
    }
  }

  Future<bool> markAsMovedToInventory(int orderId) async {
    lastError = null;
    try {
      await client
          .from('production_batches')
          .update({'moved_to_inventory': true})
          .eq('order_id', orderId);

      return true;
    } catch (e) {
      lastError = 'Failed to mark batch as moved: $e';
      return false;
    }
  }
}
