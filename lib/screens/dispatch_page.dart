import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/production_batch_order.dart';
import '../models/shipment.dart';
import '../services/orders_service.dart';
import '../services/production_batch_order_service.dart';
import '../services/shipment_service.dart';
import '../widgets/back_to_dashboard.dart';
import '../widgets/wire_card.dart';

class DispatchPage extends StatefulWidget {
  const DispatchPage({super.key});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  List<Order> _inProductionOrders = [];
  List<Order> _readyOrders = [];
  bool _isLoading = true;
  final ProductionBatchOrderService _batchService =
      ProductionBatchOrderService();
  final ShipmentService _shipmentService = ShipmentService();

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
        _inProductionOrders =
            orders.where((o) => o.productionStatus == 'in_production').toList();
        _readyOrders =
            orders.where((o) => o.productionStatus == 'ready').toList();
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

  void _showMoveToReadyDialog(Order order) {
    final batchNoController = TextEditingController();
    final batchDetailsController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Move to Ready'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: batchNoController,
                  decoration: InputDecoration(
                    labelText: 'Batch Number *',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: batchDetailsController,
                  decoration: InputDecoration(
                    labelText: 'Batch Details',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (batchNoController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Batch number is required')),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _moveToReady(
                    order,
                    batchNoController.text.trim(),
                    batchDetailsController.text.trim(),
                  );
                },
                child: Text('Move to Ready'),
              ),
            ],
          ),
    );
  }

  Future<void> _moveToReady(
    Order order,
    String batchNo,
    String batchDetails,
  ) async {
    try {
      // Create production batch
      final batch = ProductionBatchOrder(
        orderId: order.id!,
        batchNo: batchNo,
        batchDetails: batchDetails,
      );

      final createdBatch = await _batchService.create(batch);
      if (createdBatch == null) {
        throw Exception(_batchService.lastError ?? 'Failed to create batch');
      }

      // Update order status
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
        productionStatus: 'ready',
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
        totalAmount: order.totalAmount,
      );

      final success = await OrdersService.instance.updateOrder(updatedOrder);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Order moved to ready')));
        _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update order')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _shipOrder(Order order) async {
    // Confirm shipping
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Ship Order?'),
            content: Text(
              'This will move the order to history and mark it as shipped.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Ship'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      // Get current date for dispatch
      final dispatchDate = DateTime.now().toIso8601String().split('T')[0];

      // Create shipment record
      final shipment = Shipment(orderId: order.id!, shippedAt: dispatchDate);

      final createdShipment = await _shipmentService.create(shipment);
      if (createdShipment == null) {
        throw Exception(
          _shipmentService.lastError ?? 'Failed to create shipment',
        );
      }

      // Update order status to shipped with dispatch_date set
      final updatedOrder = Order(
        id: order.id,
        orderNumber: order.orderNumber,
        customerId: order.customerId,
        clientName: order.clientName,
        advancePaid: order.advancePaid,
        dueDate: order.dueDate,
        dispatchDate: dispatchDate, // Set the dispatch date!
        isAdvancePaid: order.isAdvancePaid,
        afterDispatchDays: order.afterDispatchDays,
        finalDueDate: order.finalDueDate,
        finalPaymentDate: order.finalPaymentDate,
        orderStatus: 'dispatched',
        paymentStatus: order.paymentStatus,
        productionStatus: 'shipped',
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
        totalAmount: order.totalAmount,
      );

      final success = await OrdersService.instance.updateOrder(updatedOrder);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Order shipped successfully')));
        _loadOrders();
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to ship order')));
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
        title: Text('Dispatch Management'),
        leading: BackToDashboardButton(),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // In Production Section
                    Text(
                      'In Production',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    SizedBox(height: 12),
                    if (_inProductionOrders.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No orders in production',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ..._inProductionOrders.map(
                        (order) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildOrderCard(order, isProduction: true),
                        ),
                      ),

                    SizedBox(height: 24),

                    // Ready Section
                    Text(
                      'Ready for Dispatch',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 12),
                    if (_readyOrders.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No orders ready',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ..._readyOrders.map(
                        (order) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildOrderCard(order, isProduction: false),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildOrderCard(Order order, {required bool isProduction}) {
    return WireCard(
      title: order.orderNumber ?? 'Order #${order.id}',
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.clientName ?? 'N/A',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: OrdersService.instance.getOrderItemsForOrder(order.id!),
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
            if (order.dispatchDate != null)
              Text('Dispatch Date: ${order.dispatchDate}'),
            Text('Total: \u20b9${order.totalAmount.toStringAsFixed(2)}'),
            SizedBox(height: 12),
            if (isProduction)
              ElevatedButton.icon(
                icon: Icon(Icons.check_circle),
                label: Text('Move to Ready'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showMoveToReadyDialog(order),
              )
            else
              ElevatedButton.icon(
                icon: Icon(Icons.local_shipping),
                label: Text('Ship Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _shipOrder(order),
              ),
          ],
        ),
      ),
    );
  }
}
