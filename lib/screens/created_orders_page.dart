import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/orders_service.dart';
import '../widgets/back_to_dashboard.dart';
import '../widgets/wire_card.dart';

class CreatedOrdersPage extends StatefulWidget {
  const CreatedOrdersPage({super.key});

  @override
  State<CreatedOrdersPage> createState() => _CreatedOrdersPageState();
}

class _CreatedOrdersPageState extends State<CreatedOrdersPage> {
  List<Order> _orders = [];
  bool _isLoading = true;

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
        _orders = orders.where((o) => o.productionStatus == 'created').toList();
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

  Future<void> _forwardToProduction(Order order) async {
    try {
      final updatedOrder = Order(
        id: order.id,
        orderNumber: order.orderNumber,
        customerId: order.customerId,
        clientName: order.clientName,
        advancePaid: order.advancePaid,
        dueDate: order.dueDate,
        dispatchDate: order.dispatchDate,
        isAdvancePaid: order.isAdvancePaid,
        afterDispatchDays: order.afterDispatchDays,
        finalDueDate: order.finalDueDate,
        finalPaymentDate: order.finalPaymentDate,
        orderStatus: order.orderStatus,
        paymentStatus: order.paymentStatus,
        productionStatus: 'in_production',
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
        totalAmount: order.totalAmount,
      );

      final success = await OrdersService.instance.updateOrder(updatedOrder);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Order moved to production')));
        _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to move order')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
        leading: const BackToDashboardButton(),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Created Orders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Orders awaiting production',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _orders.isEmpty
              ? Center(
                child: Text(
                  'No created orders',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  return WireCard(
                    title: order.orderNumber ?? 'Order #${order.id}',
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.clientName ?? 'N/A',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          FutureBuilder<List<dynamic>>(
                            future: OrdersService.instance
                                .getOrderItemsForOrder(order.id!),
                            builder: (context, snapshot) {
                              final items = snapshot.data ?? [];
                              final productsText =
                                  items.isEmpty
                                      ? 'No products'
                                      : items
                                          .map(
                                            (i) =>
                                                '${i?.productName ?? ''} (Qty: ${i?.quantity ?? ''})',
                                          )
                                          .join(', ');
                              return Text('Products: $productsText');
                            },
                          ),
                          Text('Due Date: ${order.dueDate}'),
                          Text(
                            'Total: \u20b9${order.totalAmount.toStringAsFixed(2)}',
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: Icon(Icons.arrow_forward),
                            label: Text('Move to Production'),
                            onPressed: () => _forwardToProduction(order),
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
