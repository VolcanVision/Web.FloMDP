import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// header widget no longer used in this screen
import '../../services/supabase_service.dart';
import '../../services/shipment_service.dart';
// Sidebar removed in favor of a bento-style menu
import '../../widgets/todo_list_widget.dart';
import '../../services/purchases_service.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/calendar_task.dart';
import '../../services/orders_service.dart';
import '../../theme/pastel_colors.dart';
import '../../widgets/help_support_dialog.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ],
    );
  }

  void _showBentoMenuDialog(BuildContext context) {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.list_alt, 'label': 'Orders', 'route': '/admin/new-order'},
      {
        'icon': Icons.build,
        'label': 'Production',
        'route': '/production/queue',
      },
      {
        'icon': Icons.inventory_2,
        'label': 'Inventory',
        'route': '/admin/inventory',
      },
      {'icon': Icons.science, 'label': 'Lab Tests', 'route': '/admin/lab-test'},
      {
        'icon': Icons.calendar_today,
        'label': 'Calendar',
        'route': '/admin/calendar',
      },
      {'icon': Icons.calculate, 'label': 'Cost', 'route': '/admin/calculator'},
      {'icon': Icons.history, 'label': 'History', 'route': '/admin/history'},
      {
        'icon': Icons.add_shopping_cart,
        'label': 'Purchases',
        'route': '/accounts/purchase',
      },
      {
        'icon': Icons.account_circle,
        'label': 'Accounts',
        'route': '/admin/accounts',
      },
    ];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      transitionDuration: Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, idx) {
                  final it = items[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      final route = it['route'] as String?;
                      Navigator.of(context).pop();
                      if (route != null) {
                        // When navigating away from Admin dashboard, pass the
                        // current dashboard route so downstream screens (like
                        // ProductionQueue) can resolve the correct 'back'
                        // destination. This allows the BackToDashboardButton to
                        // return to Admin instead of the Production dashboard.
                        Navigator.pushNamed(
                          context,
                          route,
                          arguments: {'homeDashboard': '/admin/dashboard'},
                        );
                      }
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
                        SizedBox(height: 4),
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

  // Blue theme accents
  Color get _blue => Colors.blue.shade600;
  List<Order> _orders = [];
  bool _isLoading = true;
  // Dashboard stats
  int _activeOrdersCount = 0;
  int _purchasesCount = 0;
  int _salesCount = 0;
  int _productLossCount = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await OrdersService.instance.getOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
      // Load counts that depend on orders and other tables
      await _loadStats();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading orders: $e')));
    }
  }

  Future<void> _loadStats() async {
    try {
      // Active orders: consider orders that are not completed/shipped/dispatched
      final active =
          _orders.where((o) {
            final st = o.orderStatus.toLowerCase();
            return !(st == 'completed' ||
                st == 'dispatched' ||
                st == 'shipped');
          }).length;

      // Sales: count history records (delivered shipments) - same as history page
      final shipmentService = ShipmentService();
      final historyRecords = await shipmentService.getOrderHistory();
      final sales = historyRecords.take(30).length; // Match history page limit

      // Purchases count
      final purchases = await PurchasesService().fetchAll();

      // Production losses count - query directly
      final supabase = SupabaseService().client;
      final resp = await supabase.from('production_losses').select();
      final losses = (resp as List?) ?? [];

      if (!mounted) return;
      setState(() {
        _activeOrdersCount = active;
        _salesCount = sales;
        _purchasesCount = purchases.length;
        _productLossCount = losses.length;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard stats: $e')),
        );
      }
    }
  }

  // Removed: _addOrder, since add functionality was requested to be removed from this screen

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  'Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Control Center',
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
          // Settings menu replaces the old logout icon. Shows account info and actions.
          PopupMenuButton<String>(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  await _loadOrders();
                  break;
                case 'account':
                  Navigator.pushNamed(context, '/admin/accounts');
                  break;
                case 'preferences':
                  showDialog(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('Preferences'),
                          content: const Text('Preferences are coming soon.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  );
                  break;
                case 'help':
                  HelpSupportDialog.show(context);
                  break;
                case 'logout':
                  try {
                    await SupabaseService().signOut();
                  } catch (_) {}
                  Navigator.pushReplacementNamed(context, '/login');
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
                      Text(
                        'Admin: $email',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Account ID: $uid',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: const [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 8),
                      Text('Refresh data'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'account',
                  child: Row(
                    children: const [
                      Icon(Icons.account_circle, size: 18),
                      SizedBox(width: 8),
                      Text('Account settings'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'preferences',
                  child: Row(
                    children: const [
                      Icon(Icons.tune, size: 18),
                      SizedBox(width: 8),
                      Text('Preferences'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'help',
                  child: Row(
                    children: const [
                      Icon(Icons.help_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Help & support'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: const [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator(color: _blue))
                : SafeArea(
                  bottom: true,
                  maintainBottomViewPadding: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewportHeight = constraints.maxHeight;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: viewportHeight,
                          ),
                          child: _buildRightColumn(),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top-level 2x2 stats grid (placed below header and above Todos)
        _buildStatsGrid(),

        const SizedBox(height: 12),

        // Todos (admin) — reuse the TodoListWidget so tasks are fetched & grouped
        TodoListWidget(category: TaskCategory.admin),

        const SizedBox(height: 12),

        // Recent Orders card
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/admin/new-order',
                arguments: {'homeDashboard': '/admin/dashboard'},
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Orders',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._orders.take(3).map((o) => _buildOrderCard(o)),
                ],
              ),
            ),
          ),
        ),
        // Small bottom spacer to avoid tiny overflow on some platforms (taskbar/gesture areas)
        SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    // Minimal, elegant order row: left accent bar, content column, right-aligned amount & status
    final statusColor = _getPaymentStatusColor(order);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // slim accent bar
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          // main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  order.clientName ?? 'Unknown Client',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<List<OrderItem>>(
                  future: OrdersService.instance.getOrderItemsForOrder(
                    order.id!,
                  ),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    final productsText =
                        items.isEmpty
                            ? 'No products'
                            : items
                                .map(
                                  (i) =>
                                      '${i.productName} (Qty: ${i.quantity})',
                                )
                                .join(', ');
                    return Text(
                      productsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // amount and status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  order.pendingAmount == 0
                      ? 'PAID'
                      : (order.isAdvancePaid ? 'PARTIAL' : 'UNPAID'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // compute two columns with spacing
        final totalSpacing = 12.0; // space between two cards
        final cardWidth = (constraints.maxWidth - totalSpacing) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _infoCard(
                'Active Orders',
                _activeOrdersCount,
                Colors.blue.shade700,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/admin/new-order',
                    arguments: {'homeDashboard': '/admin/dashboard'},
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _infoCard(
                'Purchases',
                _purchasesCount,
                Colors.teal.shade600,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/accounts/purchase',
                    arguments: {'homeDashboard': '/admin/dashboard'},
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _infoCard(
                'Sales',
                _salesCount,
                Colors.indigo.shade600,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/admin/history',
                    arguments: {'homeDashboard': '/admin/dashboard'},
                  );
                },
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _infoCard(
                'Product Loss',
                _productLossCount,
                Colors.red.shade600,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/production/loss',
                    arguments: {'homeDashboard': '/admin/dashboard'},
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _infoCard(
    String title,
    int count,
    Color color, {
    VoidCallback? onTap,
  }) {
    // Polished card with subtle gradient background, shadow and icon
    return Container(
      decoration: BoxDecoration(
        // stronger tint so card color is more visible
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias, // To prevent ripple overflow
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // glossy highlight stripe (subtle, does not fade the whole card)
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
              // content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 200;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          count.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isNarrow ? 20 : 28,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isNarrow ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey[800],
                          ),
                        ),
                      ],
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

  Color _getPaymentStatusColor(Order order) {
    // Return softer pastel colors for the left accent bars and status tint.
    if (order.pendingAmount == 0) return PastelColors.pastelGreen;
    if (order.isAdvancePaid) return PastelColors.pastelOrange;
    return PastelColors.pastelRed;
  }

  void _showOrdersDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollCtrl) {
            String filter = '';
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                final filtered =
                    _orders.where((o) {
                      final hay =
                          '${o.clientName ?? ''} ${o.orderNumber ?? ''} ${o.totalAmount.toString()}';
                      return hay.toLowerCase().contains(filter.toLowerCase());
                    }).toList();

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Orders',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_orders.length} total',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () async {
                                await _loadOrders();
                                setStateDialog(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search product name...',
                                  prefixIcon: Icon(Icons.search),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                onChanged:
                                    (v) => setStateDialog(() {
                                      filter = v;
                                    }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                _legendDot(Colors.green, 'Paid'),
                                const SizedBox(width: 8),
                                _legendDot(Colors.orange, 'Partial'),
                                const SizedBox(width: 8),
                                _legendDot(Colors.red, 'Unpaid'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child:
                            filtered.isEmpty
                                ? Center(child: Text('No orders found'))
                                : ListView.separated(
                                  controller: scrollCtrl,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final o = filtered[index];
                                    final statusColor = _getPaymentStatusColor(
                                      o,
                                    );
                                    return Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                      clipBehavior: Clip.hardEdge,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (dialogCtx) {
                                                          return AlertDialog(
                                                            title: Text(
                                                              'Products for Order',
                                                            ),
                                                            content: FutureBuilder<
                                                              List<OrderItem>
                                                            >(
                                                              future: OrdersService
                                                                  .instance
                                                                  .getOrderItemsForOrder(
                                                                    o.id!,
                                                                  ),
                                                              builder: (
                                                                context,
                                                                snapshot,
                                                              ) {
                                                                final items =
                                                                    snapshot
                                                                        .data ??
                                                                    [];
                                                                if (snapshot
                                                                        .connectionState ==
                                                                    ConnectionState
                                                                        .waiting) {
                                                                  return Center(
                                                                    child:
                                                                        CircularProgressIndicator(),
                                                                  );
                                                                }
                                                                if (items
                                                                    .isEmpty) {
                                                                  return Text(
                                                                    'No products',
                                                                  );
                                                                }
                                                                return SizedBox(
                                                                  width: 300,
                                                                  child: ListView.builder(
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemCount:
                                                                        items
                                                                            .length,
                                                                    itemBuilder: (
                                                                      ctx,
                                                                      idx,
                                                                    ) {
                                                                      final item =
                                                                          items[idx];
                                                                      return ListTile(
                                                                        title: Text(
                                                                          item.productName,
                                                                        ),
                                                                        subtitle:
                                                                            Text(
                                                                              'Quantity: ${item.quantity}',
                                                                            ),
                                                                      );
                                                                    },
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () =>
                                                                        Navigator.of(
                                                                          dialogCtx,
                                                                        ).pop(),
                                                                child: Text(
                                                                  'Close',
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    child: FutureBuilder<
                                                      List<OrderItem>
                                                    >(
                                                      future: OrdersService
                                                          .instance
                                                          .getOrderItemsForOrder(
                                                            o.id!,
                                                          ),
                                                      builder: (
                                                        context,
                                                        snapshot,
                                                      ) {
                                                        final items =
                                                            snapshot.data ?? [];
                                                        final productsText =
                                                            items.isEmpty
                                                                ? 'No products'
                                                                : items
                                                                    .map(
                                                                      (i) =>
                                                                          '${i.productName} (Qty: ${i.quantity})',
                                                                    )
                                                                    .join(', ');
                                                        return Text(
                                                          productsText,
                                                          maxLines: 2,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                Colors
                                                                    .blue[800],
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '\u20b9${o.totalAmount.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[800],
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Flexible(
                                                        child: Text(
                                                          'Due: ${o.dueDate}',
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey[700],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: statusColor,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          o.pendingAmount == 0
                                                              ? 'PAID'
                                                              : o.isAdvancePaid
                                                              ? 'PARTIAL'
                                                              : 'UNPAID',
                                                          style: TextStyle(
                                                            color: statusColor,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          o.clientName ?? '',
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey[700],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              children: [
                                                Text(
                                                  '\u20b9${o.totalAmount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                PopupMenuButton<String>(
                                                  onSelected: (v) async {
                                                    if (v == 'delete') {
                                                      try {
                                                        await OrdersService
                                                            .instance
                                                            .deleteOrder(o.id!);
                                                        await _loadOrders();
                                                        setStateDialog(() {});
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error deleting order: $e',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  itemBuilder:
                                                      (_) => [
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  } // Close _showOrdersDialog method
} // Close _AdminDashboardState class
