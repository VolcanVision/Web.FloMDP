import 'package:flutter/material.dart';
import '../widgets/wire_card.dart';
import '../widgets/todo_list_widget.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import '../services/supabase_service.dart';
// import '../models/alert.dart'; // Alerts removed
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Orders Card
              // Active Orders Card grid-style
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return FutureBuilder<List<Order>>(
                    future: fetchActiveOrdersNotShipped(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final int activeOrders = snapshot.data?.length ?? 0;
                      final Color color = Colors.deepPurple.shade700;

                      return SizedBox(
                        width: cardWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(color: color.withOpacity(0.12)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.pushNamed(context, '/production/dispatch');
                              },
                              child: Stack(
                                children: [
                                  // Glossy highlight stripe
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
                                            colors: [
                                              Colors.white.withOpacity(0.28),
                                              Colors.white.withOpacity(0.0),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14.0,
                                      vertical: 18,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '$activeOrders',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Active Orders',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: color.withOpacity(0.8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              
              const SizedBox(height: 16),

              
              // Todo List - full width
              TodoListWidget(category: TaskCategory.production),
              
              const SizedBox(height: 16),
              
              // Inventory Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.teal.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Inventory',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View Inventory'),
                        onPressed: () => _showImprovedInventoryDialog(context, inventoryService),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showImprovedInventoryDialog(BuildContext context, InventoryService inventoryService) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade600, Colors.teal.shade400],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Inventory Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: FutureBuilder<List<InventoryItem>>(
                  future: inventoryService.fetchAll(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No inventory items found.'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final required = item.minQuantity ?? 0;
                        final stock = item.quantity;
                        final diff = stock - required;
                        final isLow = diff < 0;
                        
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLow ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isLow ? Colors.red.shade200 : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isLow ? Icons.warning_amber : Icons.check_circle,
                                  color: isLow ? Colors.red.shade600 : Colors.green.shade600,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Stock: ${stock.toStringAsFixed(0)} | Min: $required',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isLow ? Colors.red.shade600 : Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isLow ? 'LOW' : 'OK',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              // Show as grid
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, idx) {
                final it = items[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final route = it['route'] as String?;
                    final args = ModalRoute.of(context)?.settings.arguments;
                    Navigator.of(context).pop();
                    if (route != null) Navigator.pushNamed(context, route, arguments: args);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue[600],
                        radius: 20,
                        child: Icon(
                          it['icon'] as IconData,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        it['label'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
