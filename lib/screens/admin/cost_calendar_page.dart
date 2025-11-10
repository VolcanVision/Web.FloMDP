import 'package:flutter/material.dart';
import '../../widgets/back_to_dashboard.dart';

class CostCalendarPage extends StatelessWidget {
  const CostCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackToDashboardButton(),
        title: const Text('Cost Calendar'),
      ),
      body: const Center(child: Text('Cost Calendar - To be implemented')),
    );
  }
}
