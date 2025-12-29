import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_supabase_service.dart';
import '../models/purchase.dart';

class PurchasesService extends BaseSupabaseService {
  String? lastError;

  Future<List<Purchase>> fetchAll() async {
    try {
      final res = await client
          .from('purchases')
          .select()
          .order('purchase_date', ascending: false);
      return (res as List).map((e) => Purchase.fromMap(e)).toList();
    } catch (e) {
      lastError = 'Fetch failed: $e';
      return [];
    }
  }

  Future<Purchase?> fetchById(int id) async {
    try {
      final res = await client
          .from('purchases')
          .select()
          .eq('id', id)
          .single();
      return Purchase.fromMap(res);
    } catch (e) {
      lastError = 'Fetch by ID failed: $e';
      return null;
    }
  }

  Future<Purchase?> create(Purchase purchase) async {

    lastError = null;
    final base = purchase.toMap()..remove('id');

    try {
      final res = await client.from('purchases').insert(base).select().single();
      return Purchase.fromMap(res);
    } on PostgrestException catch (e) {
      lastError = 'Database error: ${e.message}';
      return null;
    } catch (e) {
      lastError = 'Unexpected error: $e';
      return null;
    }
  }

  Future<bool> update(Purchase purchase) async {
    if (purchase.id == null) return false;
    try {
      await client
          .from('purchases')
          .update(purchase.toMap())
          .eq('id', purchase.id!);
      return true;
    } catch (e) {
      lastError = 'Update failed: $e';
      return false;
    }
  }

  Future<bool> remove(int id) async {
    try {
      await client.from('purchases').delete().eq('id', id);
      return true;
    } catch (e) {
      lastError = 'Delete failed: $e';
      return false;
    }
  }

  Future<List<Purchase>> fetchByCompany(String companyName) async {
    try {
      final res = await client
          .from('purchases')
          .select()
          .eq('company_name', companyName)
          .order('purchase_date', ascending: false);
      return (res as List).map((e) => Purchase.fromMap(e)).toList();
    } catch (e) {
      lastError = 'Fetch by company failed: $e';
      return [];
    }
  }

  Future<List<Purchase>> fetchByPaymentStatus(String status) async {
    try {
      final res = await client
          .from('purchases')
          .select()
          .eq('payment_status', status)
          .order('purchase_date', ascending: false);
      return (res as List).map((e) => Purchase.fromMap(e)).toList();
    } catch (e) {
      lastError = 'Fetch by status failed: $e';
      return [];
    }
  }
}
