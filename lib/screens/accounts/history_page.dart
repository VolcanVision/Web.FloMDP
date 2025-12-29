import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import '../admin/history_page.dart' as admin_history;

class AccountsHistoryPage extends StatelessWidget {
  const AccountsHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: admin_history.HistoryPage(role: UserRole.accounts),
    );
  }
}
