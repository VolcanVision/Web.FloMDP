import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_installment.dart';
import '../models/order_payment.dart';

class OrderPaymentsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ===== INSTALLMENTS =====

  /// Get all installments for an order
  Future<List<OrderInstallment>> getInstallments(int orderId) async {
    try {
      final response = await _supabase
          .from('order_installments')
          .select()
          .eq('order_id', orderId)
          .order('installment_number', ascending: true);

      return (response as List)
          .map((item) => OrderInstallment.fromMap(item))
          .toList();
    } catch (e) {
      print('Error fetching installments: $e');
      return [];
    }
  }

  /// Get all installments across orders (used for calendar markers)
  Future<List<OrderInstallment>> getAllInstallments() async {
    try {
      final response = await _supabase
          .from('order_installments')
          .select()
          .order('due_date', ascending: true);

      return (response as List)
          .map((item) => OrderInstallment.fromMap(item))
          .toList();
    } catch (e) {
      print('Error fetching all installments: $e');
      return [];
    }
  }

  /// Add a new installment
  Future<OrderInstallment?> addInstallment(OrderInstallment installment) async {
    try {
      final response =
          await _supabase
              .from('order_installments')
              .insert(installment.toMap(includeId: false))
              .select()
              .single();

      return OrderInstallment.fromMap(response);
    } catch (e) {
      print('Error adding installment: $e');
      rethrow;
    }
  }

  /// Update an installment
  Future<OrderInstallment?> updateInstallment(
    OrderInstallment installment,
  ) async {
    try {
      final response =
          await _supabase
              .from('order_installments')
              .update(installment.toMap())
              .eq('id', installment.id!)
              .select()
              .single();

      return OrderInstallment.fromMap(response);
    } catch (e) {
      print('Error updating installment: $e');
      rethrow;
    }
  }

  /// Mark installment as paid
  Future<void> markInstallmentPaid(int installmentId, bool isPaid) async {
    try {
      await _supabase
          .from('order_installments')
          .update({
            'is_paid': isPaid,
            'paid_date':
                isPaid ? DateTime.now().toIso8601String().split('T')[0] : null,
          })
          .eq('id', installmentId);
    } catch (e) {
      print('Error marking installment paid: $e');
      rethrow;
    }
  }

  /// Delete an installment
  Future<void> deleteInstallment(int installmentId) async {
    try {
      await _supabase
          .from('order_installments')
          .delete()
          .eq('id', installmentId);
    } catch (e) {
      print('Error deleting installment: $e');
      rethrow;
    }
  }

  // ===== PAYMENTS =====

  /// Get all payments for an order
  Future<List<OrderPayment>> getPayments(int orderId) async {
    try {
      final response = await _supabase
          .from('order_payments')
          .select()
          .eq('order_id', orderId)
          .order('payment_date', ascending: false);

      return (response as List)
          .map((item) => OrderPayment.fromMap(item))
          .toList();
    } catch (e) {
      print('Error fetching payments: $e');
      return [];
    }
  }

  /// Add a new payment
  Future<OrderPayment?> addPayment(OrderPayment payment) async {
    try {
      final response =
          await _supabase
              .from('order_payments')
              .insert(payment.toMap(includeId: false))
              .select()
              .single();

      return OrderPayment.fromMap(response);
    } catch (e) {
      print('Error adding payment: $e');
      rethrow;
    }
  }

  /// Update a payment
  Future<OrderPayment?> updatePayment(OrderPayment payment) async {
    try {
      final response =
          await _supabase
              .from('order_payments')
              .update(payment.toMap())
              .eq('id', payment.id!)
              .select()
              .single();

      return OrderPayment.fromMap(response);
    } catch (e) {
      print('Error updating payment: $e');
      rethrow;
    }
  }

  /// Delete a payment
  Future<void> deletePayment(int paymentId) async {
    try {
      await _supabase.from('order_payments').delete().eq('id', paymentId);
    } catch (e) {
      print('Error deleting payment: $e');
      rethrow;
    }
  }

  // ===== SUMMARY =====

  /// Get payment summary for an order
  Future<Map<String, dynamic>> getPaymentSummary(int orderId) async {
    try {
      final installments = await getInstallments(orderId);
      final payments = await getPayments(orderId);

      final totalInstallments = installments.length;
      final paidInstallments = installments.where((i) => i.isPaid).length;
      final totalInstallmentAmount = installments.fold<double>(
        0.0,
        (sum, i) => sum + (i.amount),
      );

      final totalPayments = payments.length;
      final totalPaidAmount = payments.fold<double>(
        0.0,
        (sum, p) => sum + (p.amount),
      );

      return {
        'total_installments': totalInstallments,
        'paid_installments': paidInstallments,
        'pending_installments': totalInstallments - paidInstallments,
        'total_installment_amount': totalInstallmentAmount,
        'total_payments': totalPayments,
        'total_paid_amount': totalPaidAmount,
      };
    } catch (e) {
      print('Error getting payment summary: $e');
      return {};
    }
  }
}
