import 'package:flutter/material.dart';

class BackToDashboardButton extends StatelessWidget {
  const BackToDashboardButton({super.key});

  String _resolveDashboardRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    final name = route?.settings.name ?? '';
    final args = route?.settings.arguments;
    // Always prefer an explicit homeDashboard passed along the nav stack
    if (args is Map && args['homeDashboard'] is String) {
      return args['homeDashboard'] as String;
    }
    if (name.startsWith('/admin/')) return '/admin/dashboard';
    if (name.startsWith('/production/')) return '/production/dashboard';
    if (name.startsWith('/accounts/')) return '/accounts/dashboard';
    // Fallback: try to infer from common pages
    if (name.contains('admin')) return '/admin/dashboard';
    if (name.contains('production')) return '/production/dashboard';
    if (name.contains('accounts')) return '/accounts/dashboard';
    return '/login';
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back to Dashboard',
      onPressed: () {
        final route = _resolveDashboardRoute(context);
        // Try to pop back to an existing instance of the desired dashboard if it's
        // already in the navigator stack (keeps navigation natural). Otherwise
        // replace stack and push the dashboard as a fresh route.
        bool found = false;
        Navigator.popUntil(context, (r) {
          if (r.settings.name == route) {
            found = true;
            return true;
          }
          return false;
        });

        if (!found) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            route,
            (r) => false,
            arguments: {'homeDashboard': route},
          );
        }
      },
    );
  }
}
