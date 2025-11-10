import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.admin;

  void login() async {
    final role = await AuthService.login(
      _emailController.text,
      _passwordController.text,
      _selectedRole,
    );
    if (role != null) {
      switch (role) {
        case UserRole.admin:
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
          break;
        case UserRole.production:
          Navigator.pushReplacementNamed(context, '/production/dashboard');
          break;
        case UserRole.accounts:
          Navigator.pushReplacementNamed(context, '/accounts/dashboard');
          break;
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enter email and password')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          elevation: 4,
          child: Container(
            width: 360,
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Center(
                    child: Text(
                      'Logo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email/Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                // Role Selector
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<UserRole>(
                    value: _selectedRole,
                    isExpanded: true,
                    underline: SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Admin'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.production,
                        child: Text('Production'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.accounts,
                        child: Text('Accounts'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Forgot Password clicked')),
                    ),
                    child: Text('Forgot password?'),
                  ),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: login,
                  child: SizedBox(
                    width: double.infinity,
                    child: Center(child: Text('Login')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
