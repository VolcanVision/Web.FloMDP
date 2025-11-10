import 'package:flutter/material.dart';

class SideBar extends StatelessWidget {
  final String activeRoute;
  final String role; // 'admin' | 'production' | 'accounts' | ''
  const SideBar({super.key, this.activeRoute = '/orders', this.role = ''});

  Widget _item(BuildContext ctx, IconData icon, String label, String route) {
    bool active = route == activeRoute;
    return ListTile(
      leading: Icon(icon, color: active ? Colors.blueGrey : Colors.grey),
      title: Text(
        label,
        style: TextStyle(color: active ? Colors.black87 : Colors.grey[600]),
      ),
      tileColor: active ? Colors.grey[200] : null,
      onTap: () {
        final home = role == 'admin'
            ? '/admin/dashboard'
            : role == 'production'
            ? '/production/dashboard'
            : role == 'accounts'
            ? '/accounts/dashboard'
            : '/login';
        Navigator.pushReplacementNamed(
          ctx,
          route,
          arguments: {'homeDashboard': home},
        );
      },
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      const SizedBox(height: 16),
      const Text(
        'Company Logo',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      const Divider(),
    ];

    if (role == 'admin') {
      items.addAll([
        _item(context, Icons.dashboard, 'Dashboard', '/admin/dashboard'),
        _item(context, Icons.receipt_long, 'Orders', '/admin/new-order'),
        _item(
          context,
          Icons.precision_manufacturing,
          'Production Queue',
          '/production/queue',
        ),
        _item(context, Icons.inventory, 'Inventory', '/admin/inventory'),
        _item(context, Icons.calendar_today, 'Calendar', '/admin/calendar'),
        _item(context, Icons.calculate, 'Cost Calculator', '/admin/calculator'),
        _item(
          context,
          Icons.account_balance,
          'Accounts (Admin)',
          '/admin/accounts',
        ),
        _item(context, Icons.science, 'Lab Test', '/admin/lab-test'),
        _item(context, Icons.history, 'History', '/admin/history'),
      ]);
    } else if (role == 'production') {
      items.addAll([
        _item(
          context,
          Icons.dashboard_customize,
          'Dashboard',
          '/production/dashboard',
        ),
        _item(
          context,
          Icons.local_shipping,
          'Dispatch',
          '/production/dispatch',
        ),
        _item(
          context,
          Icons.precision_manufacturing,
          'Production Queue',
          '/production/queue',
        ),
        _item(context, Icons.inventory, 'Inventory', '/production/inventory'),
        _item(
          context,
          Icons.calendar_today,
          'Calendar',
          '/production/calendar',
        ),
        _item(
          context,
          Icons.warning_amber,
          'Production Loss',
          '/production/loss',
        ),
        _item(context, Icons.history, 'History', '/production/history'),
      ]);
    } else if (role == 'accounts') {
      items.addAll([
        _item(context, Icons.dashboard, 'Dashboard', '/accounts/dashboard'),
        _item(context, Icons.list_alt, 'Orders', '/accounts/orders'),
        _item(context, Icons.history, 'History', '/accounts/history'),
        _item(context, Icons.shopping_cart, 'Purchases', '/accounts/purchase'),
        _item(context, Icons.calendar_today, 'Calendar', '/accounts/calendar'),
      ]);
    } else {
      // Fallback
      items.addAll([_item(context, Icons.home, 'Home', '/login')]);
    }

    items.add(const Divider());
    items.add(
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Log Out', style: TextStyle(color: Colors.red)),
        onTap: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
    return Drawer(
      child: SafeArea(child: ListView(children: items)),
    );
  }
}
