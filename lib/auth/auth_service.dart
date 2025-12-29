import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

enum UserRole { admin, production, accounts, lab_testing }

class AuthService {
  static final _supabase = Supabase.instance.client;

  // 1. Bypass / Predefined users (no password required)
  static final Map<String, UserRole> _bypassUsers = {
    'admin1': UserRole.admin,
    'admin2': UserRole.admin,
    'prod1': UserRole.production,
    'prod2': UserRole.production,
    'acc1': UserRole.accounts,
    'acc2': UserRole.accounts,
    'lab1': UserRole.lab_testing,
    'lab2': UserRole.lab_testing,
  };

  /// Log in logic:
  /// 1. Check if identifier is in _bypassUsers. If so, return role immediately.
  /// 2. If not, check "users" table matching username/email AND hashed password.
  static Future<UserRole?> login(String identifier, String password) async {
    // Check bypass list first
    if (_bypassUsers.containsKey(identifier)) {
      return _bypassUsers[identifier];
    }

    // Proper authentication
    try {
      final hashedPassword = _hashPassword(password);
      
      final response = await _supabase
          .from('users')
          .select('role, username, email')
          .or('username.eq."$identifier",email.eq."$identifier"')
          .eq('password_hash', hashedPassword) // Check password match
          .maybeSingle();

      if (response != null) {
        final roleStr = response['role'] as String;
        return _mapStringToRole(roleStr);
      }
    } catch (e) {
      print('Login error: $e');
    }
    return null;
  }

  /// Sign up logic:
  /// - Create a new user in the public.users table.
  /// - Passwords are stored as SHA-256 hashes.
  static Future<bool> signup({
    required String username,
    required String email,
    required String password,
    UserRole role = UserRole.production, // Default role
  }) async {
    try {
      final hashedPassword = _hashPassword(password);
      
      await _supabase.from('users').insert({
        'username': username,
        'email': email,
        'password_hash': hashedPassword,
        'role': role.name,
      });
      return true;
    } catch (e) {
      print('Signup error: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    // For now, logout just clears local state if we had any.
    // In future, this will call _supabase.auth.signOut();
  }

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static UserRole _mapStringToRole(String roleStr) {
    return UserRole.values.firstWhere(
      (e) => e.name == roleStr,
      orElse: () => UserRole.production,
    );
  }

  // Temporary helper to check if we are in "dev login" mode
  static bool get isDevMode => true;
}
