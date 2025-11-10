import 'package:flutter/material.dart';
import '../widgets/wire_card.dart';
import '../widgets/todo_list_widget.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import '../services/supabase_service.dart';
import '../models/alert.dart';
import '../models/order.dart';
import '../services/orders_service.dart';
import '../models/calendar_task.dart' show TaskCategory;
// Sidebar removed from layout

String _age(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 1) return '${diff.inDays}d';
  if (diff.inHours >= 1) return '${diff.inHours}h';
  return '${diff.inMinutes}m';
}

class ProductionDashboardPage extends StatelessWidget {
  const ProductionDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Alert> alerts = [
      Alert(
        title: 'Low stock: Glue',
        description: 'Glue below minimum',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    final InventoryService inventoryService = InventoryService();
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 76,
        centerTitle: false,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Production',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Operations',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(Icons.grid_view, color: Colors.white, size: 26),
              tooltip: 'Open Menu',
              onPressed: () => _showProductionBentoMenu(context),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  // Recreate page to refresh
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(pageBuilder: (_, __, ___) => const ProductionDashboardPage()),
                  );
                  break;
                case 'logout':
                  try {
                    await SupabaseService().signOut();
                  } catch (_) {}
                  Navigator.pushReplacementNamed(context, '/login');
                  break;
                case 'help':
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Help & Support'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('For support, contact:'),
                          SizedBox(height: 8),
                          Text('support@yourcompany.com'),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (ctx) {
              final user = SupabaseService().client.auth.currentUser;
              final email = user?.email ?? 'Unknown';
              final uid = user?.id ?? 'n/a';
              return [
                PopupMenuItem<String>(
                  value: 'user',
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User: $email', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Account ID: $uid', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(value: 'refresh', child: Row(children: const [Icon(Icons.refresh, size: 18), SizedBox(width: 8), Text('Refresh dashboard')])),
                PopupMenuItem<String>(value: 'help', child: Row(children: const [Icon(Icons.help_outline, size: 18), SizedBox(width: 8), Text('Help & support')])),
                const PopupMenuDivider(),
                PopupMenuItem<String>(value: 'logout', child: Row(children: const [Icon(Icons.logout, size: 18, color: Colors.red), SizedBox(width: 8), Text('Logout', style: TextStyle(color: Colors.red))])),
              ];
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      // Sidebar removed — show logout in app bar instead
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (Bento menu removed from body; header grid button opens the dialog)
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  SizedBox(
                    width: 200,
                    child: FutureBuilder<List<Order>>(
                      future: fetchActiveOrdersNotShipped(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: \\${snapshot.error}'),
                          );
                        }
                        final int activeOrders = snapshot.data?.length ?? 0;
                        // Admin-style info card
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(color: Colors.deepPurple.shade50),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 6,
                                  left: -40,
                                  right: -40,
                                  child: Transform.rotate(
                                    angle: -0.35,
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0.0)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$activeOrders',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Active Orders',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[900],
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // To-Do Section — reuse the Admin/Accounts TodoListWidget for parity
                TodoListWidget(category: TaskCategory.production),
                SizedBox(
                  width: 380,
                  child: WireCard(
                    title: 'Alerts',
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Alert creation coming soon!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_alert),
                            label: const Text('Add Alert'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...alerts.map(
                          (a) => Card(
                            color: Colors.orange[50],
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            child: ListTile(
                              leading: const Icon(
                                Icons.notification_important,
                                color: Colors.orange,
                              ),
                              title: Text(
                                a.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(a.description),
                              trailing: Tooltip(
                                message: 'Created ${_age(a.createdAt)} ago',
                                child: Text(_age(a.createdAt)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 380,
                  child: WireCard(
                    title: 'Inventory',
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.inventory_2),
                      label: const Text('View Inventory'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Inventory Items'),
                              content: SizedBox(
                                width: 400,
                                child: FutureBuilder<List<InventoryItem>>(
                                  future: inventoryService.fetchAll(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Text('Error: \\${snapshot.error}');
                                    }
                                    final items = snapshot.data ?? [];
                                    if (items.isEmpty) {
                                      return const Text(
                                        'No inventory items found.',
                                      );
                                    }
                                    return ListView(
                                      shrinkWrap: true,
                                      children:
                                          items.map((i) {
                                            final int required =
                                                i.minQuantity ?? 0;
                                            final double stock = i.quantity;
                                            final double total =
                                                stock - required;
                                            final color =
                                                total < 0
                                                    ? Colors.red
                                                    : Colors.green;
                                            return ListTile(
                                              leading: Icon(
                                                Icons.circle,
                                                color: color,
                                                size: 18,
                                              ),
                                              title: Text(i.name),
                                              subtitle: Text(
                                                'Stock: \\${stock.toStringAsFixed(2)}, Required: \\${required}',
                                              ),
                                            );
                                          }).toList(),
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      )
    );
  }

  Future<List<Order>> fetchActiveOrdersNotShipped() async {
    final orders = await OrdersService.instance.getOrders();
    // Active = status is 'new' OR status is not 'dispatched'
    return orders.where((order) {
      final s = order.orderStatus.toString().toLowerCase();
      return s != 'dispatched' && s != 'shipped';
    }).toList();
  }
}

void _showProductionBentoMenu(BuildContext context) {
  final items = <Map<String, dynamic>>[
    {'icon': Icons.list_alt, 'label': 'Queue', 'route': '/production/queue'},
    {'icon': Icons.local_shipping, 'label': 'Dispatch', 'route': '/production/dispatch'},
    {'icon': Icons.inventory_2, 'label': 'Inventory', 'route': '/production/inventory'},
    {'icon': Icons.history, 'label': 'History', 'route': '/production/history'},
    {'icon': Icons.calendar_today, 'label': 'Calendar', 'route': '/production/calendar'},
    {'icon': Icons.report_problem, 'label': 'Losses', 'route': '/production/loss'},
  ];

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Menu',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _buildBentoMenu(ctx, items),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return Transform.scale(
        scale: anim.value,
        child: Opacity(opacity: anim.value, child: child),
      );
    },
  );
}

Widget _buildBentoMenu(BuildContext context, List<Map<String, dynamic>> items) {
  const int cols = 3;
  const double spacing = 8;

  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double tileWidth = (totalWidth - (spacing * (cols - 1))) / cols;
          final double tileHeight = tileWidth * 0.85;
          final int rows = (items.length / cols).ceil();
          final double gridHeight = rows * tileHeight + (rows - 1) * spacing;

          return SizedBox(
            height: gridHeight,
            child: GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: cols,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: tileWidth / tileHeight,
              physics: const NeverScrollableScrollPhysics(),
              children:
                  items.map((it) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final route = it['route'] as String?;
                        if (route != null) Navigator.pushNamed(context, route);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue.shade50,
                              child: Icon(
                                it['icon'] as IconData,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: Text(
                                it['label'],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          );
        },
      ),
    ),
  );
}
