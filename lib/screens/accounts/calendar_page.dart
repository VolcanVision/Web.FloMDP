import 'package:flutter/material.dart';
import '../calendar_page.dart' as calendar;

class AccountsCalendarPage extends StatelessWidget {
  const AccountsCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: calendar.CalendarPage(),
    );
  }
}
