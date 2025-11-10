import 'package:flutter/material.dart';
import '../shared/accounts_page.dart';

class AccountsDashboard extends StatelessWidget {
  const AccountsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SharedAccountsPage(role: 'accounts');
  }
}
