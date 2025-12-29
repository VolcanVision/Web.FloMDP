import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_supabase_service.dart';
import '../models/customer.dart';

class CustomersService extends BaseSupabaseService {
  String? lastError;

  Future<List<Customer>> fetchAll() async {
    try {
      final res = await client.from('customers').select().order('company_name');
      return (res as List).map((e) => Customer.fromMap(e)).toList();
    } catch (e) {
      lastError = 'Fetch failed: $e';
      return [];
    }
  }

  Future<Customer?> create(Customer customer) async {
    lastError = null;
    final base = customer.toMap()..remove('id');
    Future<Customer?> _attemptInsert(Map<String, dynamic> data) async {
      final res = await client.from('customers').insert(data).select().single();
      return Customer.fromMap(res);
    }

    try {
      return await _attemptInsert({...base});
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('is_active') || e.code == 'PGRST204') {
        final retry = {...base}..remove('is_active');
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

  Future<bool> update(Customer customer) async {
    if (customer.id == null) return false;
    try {
      await client
          .from('customers')
          .update(customer.toMap())
          .eq('id', customer.id!);
      return true;
    } catch (e) {
      lastError = 'Update failed: $e';
      return false;
    }
  }

  Future<bool> remove(int id) async {
    try {
      await client.from('customers').delete().eq('id', id);
      return true;
    } catch (e) {
      lastError = 'Delete failed: $e';
      return false;
    }
  }
}
