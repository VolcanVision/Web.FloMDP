import 'package:flutter/material.dart';

class BackToDashboardButton extends StatelessWidget {
  const BackToDashboardButton({super.key});

  String _resolveDashboardRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    final name = route?.settings.name ?? '';
    final args = route?.settings.arguments;
    
    print('BackToDashboardButton._resolveDashboardRoute: name="$name", args=$args, argsType=${args.runtimeType}');
    
    // Always prefer an explicit homeDashboard passed along the nav stack
    if (args is Map && args['homeDashboard'] is String) {
      final home = args['homeDashboard'] as String;
      print('BackToDashboardButton: Using homeDashboard from args: "$home"');
      return home;
    }
    
    String resolved;
    if (name.startsWith('/admin/')) {
      resolved = '/admin/dashboard';
    } else if (name.startsWith('/production/')) {
      resolved = '/production/dashboard';
    } else if (name.startsWith('/accounts/')) {
      resolved = '/accounts/dashboard';
    } else if (name.startsWith('/lab_testing/')) {
      resolved = '/lab_testing/dashboard';
    } else if (name.contains('admin')) {
      resolved = '/admin/dashboard';
    } else if (name.contains('production')) {
      resolved = '/production/dashboard';
    } else if (name.contains('accounts')) {
      resolved = '/accounts/dashboard';
    } else if (name.contains('lab_testing')) {
      resolved = '/lab_testing/dashboard';
    } else {
      resolved = '/login';
    }
    
    print('BackToDashboardButton: No homeDashboard in args, resolved by route prefix to: "$resolved"');
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back to Dashboard',
      onPressed: () {
        final route = _resolveDashboardRoute(context);
        print('BackToDashboardButton: Target route: "$route"');
        
        // Print the full route stack for debugging
        print('BackToDashboardButton: Scanning navigator stack...');
        
        bool found = false;
        Navigator.popUntil(context, (r) {
           final name = r.settings.name;
           final rArgs = r.settings.arguments;
           print('BackToDashboardButton: Stack route: "$name", args: $rArgs');
          if (name == route) {
            found = true;
            print('BackToDashboardButton: MATCH FOUND, stopping pop.');
            return true;
          }
          return false;
        });

        if (!found) {
           print('BackToDashboardButton: Target not in stack. Pushing "$route" fresh.');
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
