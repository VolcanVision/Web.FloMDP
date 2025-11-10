import 'package:flutter/material.dart';
import '../shared/accounts_page.dart';

class AdminAccountsPage extends StatelessWidget {
  const AdminAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SharedAccountsPage(role: 'admin');
  }
}
