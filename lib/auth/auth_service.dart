enum UserRole { admin, production, accounts }

class AuthService {
  // Simple in-memory auth for wireframe. Replace with real auth later.
  static Future<UserRole?> login(
    String username,
    String password,
    UserRole role,
  ) async {
    await Future.delayed(Duration(milliseconds: 300));
    // Accept any non-empty credentials for the prototype
    if (username.isNotEmpty && password.isNotEmpty) return role;
    return null;
  }
}
