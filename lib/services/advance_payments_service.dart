import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/advance_payment.dart';

class AdvancePaymentsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'advances';

  // Singleton pattern
  static final AdvancePaymentsService _instance =
      AdvancePaymentsService._internal();
  factory AdvancePaymentsService() => _instance;
  AdvancePaymentsService._internal();
  static AdvancePaymentsService get instance => _instance;

  /// Add a new advance payment for an order
  Future<AdvancePayment> addPayment(AdvancePayment payment) async {
    // Defensive payload: only send known columns and drop nulls to avoid
    // Postgrest errors when legacy/extra keys appear in the map.
    final payload = Map<String, dynamic>.from(payment.toMap());
    // Remove null values
    payload.removeWhere((k, v) => v == null);
    // Allow-list of columns that exist in the `advances` table
    const allowed = {'order_id', 'amount', 'paid_at', 'note', 'created_at'};
    payload.removeWhere((k, v) => !allowed.contains(k));

    // Log payload for debugging (can be removed later)
    // ignore: avoid_print
    print('[AdvancePaymentsService] inserting advance payload: $payload');

    try {
      final data =
          await _supabase.from(_tableName).insert(payload).select().single();
      return AdvancePayment.fromMap(data);
    } catch (e) {
      // Log the error
      // ignore: avoid_print
      print('[AdvancePaymentsService] addPayment error: $e');

      // If the server-side error is due to a missing column (e.g. legacy trigger
      // referencing `total_cost`), attempt a safe fallback: insert without
      // requesting the returned row and then fetch the inserted payment by
      // matching order_id, amount and paid_at. This is a pragmatic fallback
      // to keep the app working while the database trigger/function is fixed.
      try {
        final lower = e.toString().toLowerCase();
        if (lower.contains('total_cost') ||
            lower.contains('column "total_cost"')) {
          // ignore: avoid_print
          print(
            '[AdvancePaymentsService] Detected total_cost DB error, attempting fallback insert',
          );
          await _supabase.from(_tableName).insert(payload);

          // Fetch payments for the order and return the most recent matching one
          final payments = await getPaymentsForOrder(payment.orderId);
          // Try to find a payment with same amount and paidAt, prefer most recent
          final match = payments.reversed.firstWhere(
            (p) => (p.amount == payment.amount) && (p.paidAt == payment.paidAt),
            orElse:
                () =>
                    payments.isNotEmpty
                        ? payments.last
                        : throw Exception('Inserted payment not found'),
          );
          return match;
        }
      } catch (e2) {
        // ignore: avoid_print
        print('[AdvancePaymentsService] fallback insert failed: $e2');
      }

      throw Exception('Failed to add advance payment: $e');
    }
  }

  /// Get all advance payments for a specific order
  Future<List<AdvancePayment>> getPaymentsForOrder(int orderId) async {
    try {
      final data = await _supabase
          .from(_tableName)
          .select()
          .eq('order_id', orderId)
          .order('paid_at', ascending: false);
      return (data as List).map((e) => AdvancePayment.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch advance payments: $e');
    }
  }

  /// Update an existing advance payment
  Future<void> updatePayment(AdvancePayment payment) async {
    try {
      await _supabase
          .from(_tableName)
          .update(payment.toMap())
          .eq('id', payment.id!);
    } catch (e) {
      throw Exception('Failed to update advance payment: $e');
    }
  }

  /// Delete an advance payment
  Future<void> deletePayment(int paymentId) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', paymentId);
    } catch (e) {
      throw Exception('Failed to delete advance payment: $e');
    }
  }

  /// Get total advance paid for an order
  Future<double> getTotalAdvancePaid(int orderId) async {
    try {
      final payments = await getPaymentsForOrder(orderId);
      return payments.fold<double>(0.0, (sum, payment) => sum + payment.amount);
    } catch (e) {
      throw Exception('Failed to calculate total advance: $e');
    }
  }

  /// Get all advances across orders (used for calendar markers)
  Future<List<AdvancePayment>> getAllAdvances() async {
    try {
      final data = await _supabase
          .from(_tableName)
          .select()
          .order('paid_at', ascending: true);
      return (data as List).map((e) => AdvancePayment.fromMap(e)).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[AdvancePaymentsService] getAllAdvances error: $e');
      return [];
    }
  }
}
