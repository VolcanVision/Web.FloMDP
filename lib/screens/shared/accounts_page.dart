import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/todo_list_widget.dart';
import '../../models/calendar_task.dart';
import '../../services/calendar_tasks_service.dart';
import '../../services/alerts_service.dart';
import '../../services/purchases_service.dart';
import '../../services/orders_service.dart';
import '../../widgets/back_to_dashboard.dart';

class SharedAccountsPage extends StatefulWidget {
  final String role; // 'admin' or 'accounts'

  const SharedAccountsPage({super.key, required this.role});

  @override
  State<SharedAccountsPage> createState() => _SharedAccountsPageState();
}

Color _menuTileColor(String label) {
  final l = label.toLowerCase();
  if (l.contains('purch')) return Colors.teal.shade600;
  if (l.contains('order')) return Colors.blue.shade700;
  if (l.contains('hist')) return Colors.indigo.shade600;
  if (l.contains('calendar')) return Colors.blueGrey.shade400;
  if (l.contains('account')) return Colors.purple.shade600;
  return Colors.blue.shade700;
}

class _SharedAccountsPageState extends State<SharedAccountsPage> {
  final CalendarTasksService _tasksService = CalendarTasksService();
  final AlertsService _alertsService = AlertsService();
  final PurchasesService _purchasesService = PurchasesService();
  final OrdersService _ordersService = OrdersService.instance;


  // Metrics
  int _pendingOrdersCount = 0;
  int _dispatchPendingCount = 0;
  int _intransitOrdersCount = 0;
  int _pendingPurchasesCount = 0;
  int _deliveredOrdersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Widget _buildAccountsStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = 8.0;
        final cardWidth = (constraints.maxWidth - totalSpacing) / 2;
        return Wrap(
          spacing: totalSpacing,
          runSpacing: totalSpacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _accountsInfoCard(
                'Pending Orders',
                _pendingOrdersCount.toString(),
                Colors.orange.shade700,
                onTap: () {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  Navigator.pushNamed(context, '/accounts/orders', arguments: args);
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _accountsInfoCard(
                'Dispatch Pending',
                _dispatchPendingCount.toString(),
                Colors.blue.shade700,
                onTap: () {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  Navigator.pushNamed(context, '/accounts/dispatch', arguments: args);
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _accountsInfoCard(
                'Intransit Orders',
                _intransitOrdersCount.toString(),
                Colors.teal.shade700,
                onTap: () {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  Navigator.pushNamed(context, '/accounts/dispatch', arguments: args);
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _accountsInfoCard(
                'Pending Purchases',
                _pendingPurchasesCount.toString(),
                Colors.purple.shade700,
                onTap: () {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  Navigator.pushNamed(context, '/accounts/purchase', arguments: args);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _accountsInfoCard(String title, String value, Color color, {VoidCallback? onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
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
                        value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
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
        ),
      ),
    );
  }

  void _showBentoMenuDialog(BuildContext context) {
    // Capture args from the PAGE's context BEFORE showing the dialog
    // This is critical - inside the dialog, ModalRoute.of(context) would return null
    final pageArgs = ModalRoute.of(context)?.settings.arguments;
    print('SharedAccountsPage: _showBentoMenuDialog called. Page args: $pageArgs');
    
    // Use the same symbols as Admin dashboard for parity
    final items = <Map<String, dynamic>>[
      {'icon': Icons.add_shopping_cart, 'label': 'Purchases', 'route': '/accounts/purchase'},
      {'icon': Icons.list_alt, 'label': 'Orders', 'route': '/accounts/orders'},
      // Dispatch removed from bento
      {'icon': Icons.history, 'label': 'History', 'route': '/accounts/history'},
      {'icon': Icons.calendar_today, 'label': 'Calendar', 'route': '/accounts/calendar'},
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
                // Show as 2x2 grid for the Accounts menu (4 items)
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (dialogContext, idx) {
                  final it = items[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      final route = it['route'] as String?;
                      print('SharedAccountsPage (Menu): Navigating to $route. Using captured args: $pageArgs');
                      Navigator.of(dialogContext).pop();
                      if (route != null) Navigator.pushNamed(context, route, arguments: pageArgs);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[600],
                          radius: 15,
                          child: Icon(
                            it['icon'] as IconData,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
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

  Future<void> _loadMetrics() async {
    try {
      final orders = await _ordersService.getOrders();
      final purchases = await _purchasesService.fetchAll();

      // 1. Pending Orders: 'new', 'pending_approval', 'confirmed'
      final pendingOrders = orders.where((o) {
        final st = o.orderStatus.toLowerCase();
        return st == 'new' || st == 'pending_approval' || st == 'confirmed';
      }).length;

      // 2. Dispatch Pending: productionStatus == 'completed' AND orderStatus != 'dispatched'
      final dispatchPending = orders.where((o) {
        final pSt = o.productionStatus.toLowerCase();
        final oSt = o.orderStatus.toLowerCase();
        return pSt == 'completed' && oSt != 'dispatched' && oSt != 'completed';
      }).length;

      // 3. Intransit Orders: 'dispatched'
      final intransitOrders = orders.where((o) => o.orderStatus.toLowerCase() == 'dispatched').length;

      // 4. Delivered Orders
      final deliveredOrders = orders.where((o) => o.orderStatus.toLowerCase() == 'delivered' || o.orderStatus.toLowerCase() == 'completed').length;

      // 4. Pending Purchases: any purchase NOT 'paid'
      final pendingPurchases = purchases.where((p) => p.paymentStatus?.toLowerCase() != 'paid').length;

      setState(() {
        _pendingOrdersCount = pendingOrders;
        _dispatchPendingCount = dispatchPending;
        _intransitOrdersCount = intransitOrders;
        _deliveredOrdersCount = deliveredOrders;
        _pendingPurchasesCount = pendingPurchases;
      });
    } catch (e) {
      debugPrint('Error loading metrics: $e');
    }
  }

  // To-Dos managed by TodoListWidget

  // Alerts helpers removed

  @override
  Widget build(BuildContext context) {
    // Sidebar removed; activeRoute not used
    final args = ModalRoute.of(context)?.settings.arguments;
    print('SharedAccountsPage: build. Role: ${widget.role}, Args: $args');

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 76,
        centerTitle: false,
        automaticallyImplyLeading: widget.role == 'admin',
        leading: (widget.role == 'admin' || (ModalRoute.of(context)?.settings.arguments as Map?)?['homeDashboard'] != null)
            ? const BackToDashboardButton()
            : null,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.role == 'admin' ? 'Accounts (Admin)' : 'Accounts',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Financials',
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
              onPressed: () => _showBentoMenuDialog(context),
            ),
          ],
        ),
        actions: widget.role == 'accounts' ? [
          // Settings menu similar to Admin header
          PopupMenuButton<String>(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  _loadMetrics();
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
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
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
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(children: const [Icon(Icons.refresh, size: 18), SizedBox(width: 8), Text('Refresh data')]),
                ),
                PopupMenuItem<String>(
                  value: 'help',
                  child: Row(children: const [Icon(Icons.help_outline, size: 18), SizedBox(width: 8), Text('Help & support')]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(children: const [Icon(Icons.logout, size: 18, color: Colors.red), SizedBox(width: 8), Text('Logout', style: TextStyle(color: Colors.red))]),
                ),
              ];
            },
          ),
        ] : [],
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // (bento menu removed here by request)
              // Metrics Cards (styled like Admin dashboard info cards)
              _buildAccountsStatsGrid(),
  
              const SizedBox(height: 24),
  
              const SizedBox(height: 24),
  
              // New Dispatch Summary Card
              _buildDispatchSummaryCard(),
  
              const SizedBox(height: 24),
              // To-Do Section — reuse the Admin TodoListWidget for parity
              TodoListWidget(category: TaskCategory.accounts),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDispatchSummaryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final args = ModalRoute.of(context)?.settings.arguments;
            Navigator.pushNamed(context, '/accounts/dispatch', arguments: args);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
               children: [
                 // Icon Box
                 Container(
                   width: 48,
                   height: 48,
                   decoration: BoxDecoration(
                     color: Colors.indigo.shade50,
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Icon(Icons.local_shipping_outlined, color: Colors.indigo.shade600),
                 ),
                 const SizedBox(width: 16),
                 
                 // Label
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: const [
                       Text(
                         'Dispatch Overview',
                         style: TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: Colors.black87,
                         ),
                       ),
                       Text(
                         'Tap to manage shipments',
                         style: TextStyle(
                           fontSize: 12,
                           color: Colors.grey,
                         ),
                       ),
                     ],
                   ),
                 ),
                 
                 const Icon(Icons.chevron_right, color: Colors.grey),
               ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

Widget _buildBentoMenu(BuildContext context, List<Map<String, dynamic>> items) {
  const double spacing = 8;

  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth;
          // Use a responsive minimum tile width so tiles wrap naturally on small screens
          const double minTileWidth = 120;
          final int cols = (maxWidth / (minTileWidth + spacing)).floor().clamp(
            1,
            4,
          );
          final double tileWidth = (maxWidth - (spacing * (cols - 1))) / cols;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children:
                items.map((it) {
                  return SizedBox(
                    width: tileWidth,
                    child: InkWell(
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
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue[600],
                              radius: 15,
                              child: Icon(
                                it['icon'] as IconData,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                      ),
                    ),
                  );
                }).toList(),
          );
        },
      ),
    ),
  );
}

