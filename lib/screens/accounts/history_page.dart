import 'package:flutter/material.dart';
import '../admin/history_page.dart' as admin_history;
import '../../services/supabase_service.dart';

class AccountsHistoryPage extends StatelessWidget {
  const AccountsHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await SupabaseService().signOut();
              } catch (_) {}
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: admin_history.HistoryPage(),
    );
  }
}
