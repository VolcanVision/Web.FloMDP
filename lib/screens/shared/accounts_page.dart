import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../widgets/wire_card.dart';
import '../../widgets/todo_list_widget.dart';
import '../../models/calendar_task.dart';
import '../../models/alert.dart';
import '../../services/calendar_tasks_service.dart';
import '../../services/alerts_service.dart';
import '../../services/purchases_service.dart';
import '../../services/orders_service.dart';

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

  List<CalendarTask> _todos = [];
  List<Alert> _alerts = [];
  bool _isLoadingTodos = true;
  bool _isLoadingAlerts = true;

  // Metrics
  int _totalPurchases = 0; // Change type to int to store count of purchases
  double _totalSales = 0;
  int _dispatchPendingCount = 0;
  int _approvedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _loadAlerts();
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
              child: _accountsInfoCard('Purchases', _totalPurchases.toString(), Colors.teal.shade600),
            ),
            SizedBox(
              width: cardWidth,
              child: _accountsInfoCard('Sales', '\$${_totalSales.toStringAsFixed(0)}', Colors.green.shade700),
            ),
            SizedBox(
              width: cardWidth,
              child: _accountsInfoCard('Dispatch Pending', _dispatchPendingCount.toString(), Colors.blue.shade700),
            ),
            SizedBox(
              width: cardWidth,
              child: _accountsInfoCard('Approved', _approvedCount.toString(), Colors.purple.shade700),
            ),
          ],
        );
      },
    );
  }

  Widget _accountsInfoCard(String title, String value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
    );
  }

  void _showBentoMenuDialog(BuildContext context) {
    // Use the same symbols as Admin dashboard for parity
    final items = <Map<String, dynamic>>[
      {'icon': Icons.add_shopping_cart, 'label': 'Purchases', 'route': '/accounts/purchase'},
      {'icon': Icons.list_alt, 'label': 'Orders', 'route': '/accounts/orders'},
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
                itemBuilder: (context, idx) {
                  final it = items[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      final route = it['route'] as String?;
                      Navigator.of(context).pop();
                      if (route != null) Navigator.pushNamed(context, route);
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
      // Purchases
      final purchases = await _purchasesService.fetchAll();
      final purchaseCount = purchases.length; // Count of purchases

      // Sales
      final orders = await _ordersService.getOrders();
      final totalSales = orders.fold<double>(
        0,
        (sum, o) => sum + o.totalAmount,
      );

      // Dispatch Pending (production_status = 'completed')
      final dispatchPending =
          orders
              .where((o) => o.productionStatus.toLowerCase() == 'completed')
              .length;

      // Approved (orderStatus = 'approved')
      final approved =
          orders.where((o) => o.orderStatus.toLowerCase() == 'approved').length;

      setState(() {
        _totalPurchases = purchaseCount; // Update to use count
        _totalSales = totalSales;
        _dispatchPendingCount = dispatchPending;
        _approvedCount = approved;
      });
    } catch (e) {
      debugPrint('Error loading metrics: $e');
    }
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoadingTodos = true);
    try {
      final allTasks = await _tasksService.fetchAll();
      // Filter for accounts category and incomplete tasks
      setState(() {
        _todos =
            allTasks
                .where(
                  (task) =>
                      task.category == TaskCategory.accounts &&
                      !task.isCompleted,
                )
                .toList();
        _isLoadingTodos = false;
      });
    } catch (e) {
      setState(() => _isLoadingTodos = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading todos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoadingAlerts = true);
    try {
      final allAlerts = await _alertsService.fetchAll();
      // Show only unread alerts
      setState(() {
        _alerts = allAlerts.where((alert) => !alert.isRead).toList();
        _isLoadingAlerts = false;
      });
    } catch (e) {
      setState(() => _isLoadingAlerts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading alerts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTodoComplete(CalendarTask task) async {
    final updatedTask = CalendarTask(
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
      category: task.category,
      isCompleted: !task.isCompleted,
      assignedTo: task.assignedTo,
      assignedBy: task.assignedBy,
      orderId: task.orderId,
      createdBy: task.createdBy,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
    );

    final success = await _tasksService.update(updatedTask);
    if (success) {
      _loadTodos(); // Refresh list
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: ${_tasksService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAlertRead(Alert alert) async {
    final success = await _alertsService.markRead(alert.id!, isRead: true);
    if (success) {
      _loadAlerts(); // Refresh list
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to mark as read: ${_alertsService.lastError}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getAlertColor(String alertType) {
    switch (alertType.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon(String alertType) {
    switch (alertType.toLowerCase()) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber;
      case 'success':
        return Icons.check_circle_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sidebar removed; activeRoute not used

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
                  'Accounts',
                  style: TextStyle(
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
        actions: [
          // Settings menu similar to Admin header
          PopupMenuButton<String>(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  _loadTodos();
                  _loadAlerts();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (bento menu removed here by request)
            // Metrics Cards (styled like Admin dashboard info cards)
            _buildAccountsStatsGrid(),

            const SizedBox(height: 24),

            // Alerts Section
            WireCard(
              title: 'Alerts',
              child:
                  _isLoadingAlerts
                      ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                      : _alerts.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No new alerts',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _alerts.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          final color = _getAlertColor(alert.alertType);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.1),
                              child: Icon(
                                _getAlertIcon(alert.alertType),
                                color: color,
                              ),
                            ),
                            title: Text(
                              alert.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(alert.description),
                                if (alert.createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy - hh:mm a',
                                    ).format(alert.createdAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () => _markAlertRead(alert),
                              tooltip: 'Mark as read',
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
            ),
            const SizedBox(height: 24),

            // To-Do Section — reuse the Admin TodoListWidget for parity
            TodoListWidget(category: TaskCategory.accounts),
          ],
        ),
      ),
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
