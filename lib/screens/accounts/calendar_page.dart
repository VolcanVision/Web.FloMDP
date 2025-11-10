import 'package:flutter/material.dart';
import '../calendar_page.dart' as calendar;
import '../../services/supabase_service.dart';

class AccountsCalendarPage extends StatelessWidget {
  const AccountsCalendarPage({super.key});

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
      body: calendar.CalendarPage(),
    );
  }
}
