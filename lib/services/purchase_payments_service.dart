import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_payment.dart';

class PurchasePaymentsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'purchase_payments';

  static final PurchasePaymentsService _instance = PurchasePaymentsService._internal();
  factory PurchasePaymentsService() => _instance;
  PurchasePaymentsService._internal();
  static PurchasePaymentsService get instance => _instance;

  Future<PurchasePayment> addPayment(PurchasePayment payment) async {
    final payload = payment.toMap();
    payload.remove('id');
    try {
      final res = await _supabase.from(_tableName).insert(payload).select().single();
      return PurchasePayment.fromMap(res);
    } catch (e) {
      // If table doesn't exist, this will fail. 
      // In a real environment, you'd create the table.
      throw Exception('Failed to add purchase payment: $e');
    }
  }

  Future<List<PurchasePayment>> getPaymentsForPurchase(int purchaseId) async {
    try {
      final res = await _supabase
          .from(_tableName)
          .select()
          .eq('purchase_id', purchaseId)
          .order('paid_at', ascending: false);
      return (res as List).map((e) => PurchasePayment.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deletePayment(int id) async {
    await _supabase.from(_tableName).delete().eq('id', id);
  }
}
