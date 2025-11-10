import 'package:supabase_flutter/supabase_flutter.dart';

/// Base helper to provide a shared Supabase client and common utilities.
abstract class BaseSupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  bool get isAuthenticated => client.auth.currentUser != null;
}
