import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/orders_service.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import 'package:intl/intl.dart';

class AccountsOrdersPage extends StatefulWidget {
  const AccountsOrdersPage({super.key});

  @override
  State<AccountsOrdersPage> createState() => _AccountsOrdersPageState();
}

class _AccountsOrdersPageState extends State<AccountsOrdersPage> {
  List<Order> _orders = [];
  bool _isLoading = true;
  Map<int, List<OrderItem>> _orderItemsCache = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await OrdersService.instance.getOrders();
      final itemsCache = <int, List<OrderItem>>{};
      for (final order in orders) {
        if (order.id != null) {
          final items = await OrdersService.instance.getOrderItemsForOrder(
            order.id!,
          );
          itemsCache[order.id!] = items;
        }
      }
      setState(() {
        _orders = orders;
        _orderItemsCache = itemsCache;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading orders: $e')));
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'dispatched':
        return Colors.green;
      case 'pending':
      case 'in_production':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await SupabaseService().signOut();
              } catch (_) {}
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final items = _orderItemsCache[order.id!] ?? [];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(
                          order.orderStatus,
                        ).withAlpha(50),
                        child: Icon(
                          Icons.receipt_long,
                          color: _getStatusColor(order.orderStatus),
                        ),
                      ),
                      title: Text(
                        'Order #${order.orderNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Client: ${order.clientName ?? ''}'),
                          Text(
                            'Products: ' +
                                (items.isEmpty
                                    ? 'None'
                                    : items
                                        .map(
                                          (i) =>
                                              '${i.productName} (Qty: ${i.quantity})',
                                        )
                                        .join(', ')),
                          ),
                          Text(
                            'Due: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(order.dueDate))}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    order.orderStatus,
                                  ).withAlpha(50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  order.orderStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(order.orderStatus),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      order.paymentStatus == 'paid'
                                          ? Colors.green.withAlpha(50)
                                          : Colors.orange.withAlpha(50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  order.paymentStatus.toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        order.paymentStatus == 'paid'
                                            ? Colors.green
                                            : Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\u20b9${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
