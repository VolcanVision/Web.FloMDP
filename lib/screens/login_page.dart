import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../auth/auth_service.dart';
import '../services/fcm_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Login Fields
  final _identifierController = TextEditingController(); 
  final _passwordController = TextEditingController();
  
  // Sign Up Fields
  final _signupUsernameController = TextEditingController(); 
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLogin = true; // Toggle between Login and Sign Up
  UserRole _selectedRole = UserRole.production;

  void _handleAuth() async {
    if (_isLogin) {
      // --- LOG IN LOGIC ---
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text.trim();

      if (identifier.isEmpty || password.isEmpty) {
        _showError('Please enter email and password');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final role = await AuthService.login(identifier, password);
        if (!mounted) return;

        if (role != null) {
          // Register device token for notifications (skip on web for now)
          if (!kIsWeb) {
            await FCMService().onUserLogin();
          }
          
          _navigateToDashboard(role);
        } else {
          _showError('Invalid credentials');
        }
      } catch (e) {
        _showError('Login failed: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // --- SIGN UP LOGIC ---
      final username = _signupUsernameController.text.trim();
      final email = _signupEmailController.text.trim();
      final password = _signupPasswordController.text.trim();

      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        _showError('Please fill all fields');
        return;
      }

      setState(() => _isLoading = true);
      
      try {
        // Create user with default role (production)
        // In a real app, you might want a role selector or admin-only creation
        final success = await AuthService.signup(
          username: username,
          email: email,
          password: password,
          role: _selectedRole,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please log in.'),
              backgroundColor: Colors.green,
            ),
          );

          // Switch back to login
          setState(() {
            _isLogin = true;
            _identifierController.text = username; // Auto-fill username
            _signupUsernameController.clear();
            _signupEmailController.clear();
            _signupPasswordController.clear();
          });
        } else {
          _showError('Sign up failed. Username or email might be taken.');
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
        _showError('Sign up error: $e');
      }
    }
  }

  void _navigateToDashboard(UserRole role) {
    String targetRoute;
    switch (role) {
      case UserRole.admin:
        targetRoute = '/admin/dashboard';
        break;
      case UserRole.production:
        targetRoute = '/production/dashboard';
        break;
      case UserRole.accounts:
        targetRoute = '/accounts/dashboard';
        break;
      case UserRole.lab_testing:
        targetRoute = '/lab_testing/dashboard';
        break;
    }
    Navigator.pushReplacementNamed(context, targetRoute);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // --- BLACK HEADER (25%) ---
          Expanded(
            flex: 25,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0), // increased padding to make logo relatively smaller
                  child: Image.asset(
                    'assets/MDP_logo.jpeg',
                    fit: BoxFit.contain, // Ensure logo fits cleanly inside
                    // Fallback to text if image missing (requires restart)
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          'MDP',
                          style: TextStyle(
                            fontSize: 60, 
                            fontWeight: FontWeight.w900, 
                            color: Colors.white, 
                            letterSpacing: 4
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // --- FORM SECTION (75%) ---
          Expanded(
            flex: 75,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Volcan Logo/Text
                  Center(
                    child: SizedBox(
                      height: 120, // Increased from 60 to make big
                      child: Image.asset(
                        'assets/VOLCAN_logo.png',
                        fit: BoxFit.contain,
                        // Fallback to text lockup if image missing
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'VOLCAN',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 6,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'SUPPLY CHAIN MANAGEMENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ANIMATED FORM SWITCHER
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isLogin ? _buildLoginForm() : _buildSignUpForm(),
                  ),
                  
                  const SizedBox(height: 32),

                  // SUBMIT BUTTON
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isLogin ? 'SIGN IN' : 'SIGN UP',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),

                  // TOGGLE BUTTON
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            // Clear fields when switching
                            _showError('Switched to ${_isLogin ? "Login" : "Sign Up"}');
                          });
                        },
                        child: Text(
                          _isLogin ? 'Sign Up' : 'Log In',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      children: [
        TextField(
          controller: _identifierController,
          decoration: _inputDecoration('Email or Username', Icons.person_outline),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: _inputDecoration('Password', Icons.lock_outline, isPassword: true),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      key: const ValueKey('signup'),
      children: [
        TextField(
          controller: _signupUsernameController,
          decoration: _inputDecoration('Username', Icons.person),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _signupEmailController,
          decoration: _inputDecoration('Email', Icons.email_outlined),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _signupPasswordController,
          obscureText: _obscurePassword,
          decoration: _inputDecoration('Password', Icons.lock_outline, isPassword: true),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<UserRole>(
          value: _selectedRole,
          decoration: _inputDecoration('Role', Icons.work_outline),
          items: UserRole.values.map((role) {
            String label;
            switch (role) {
              case UserRole.admin: label = 'Admin'; break;
              case UserRole.production: label = 'Production'; break;
              case UserRole.accounts: label = 'Accounts'; break;
              case UserRole.lab_testing: label = 'Lab Testing'; break;
            }
            return DropdownMenuItem(
              value: role,
              child: Text(label),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedRole = val);
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool isPassword = false}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
