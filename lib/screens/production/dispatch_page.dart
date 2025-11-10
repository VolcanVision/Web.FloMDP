import 'package:flutter/material.dart';
import '../../models/order_item.dart';
import '../../models/order.dart';
import '../../models/production_batch_order.dart';
import '../../models/shipment.dart';
import '../../services/orders_service.dart';
import '../../services/production_batch_order_service.dart';
import '../../services/shipment_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/back_to_dashboard.dart';

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final orders = await OrdersService.instance.getOrders();
      if (!mounted) return;
      setState(() {
        // Show both 'created' and 'in_production' orders in the In Production section
        _inProductionOrders =
            orders
                .where(
                  (o) =>
                      o.productionStatus == 'created' ||
                      o.productionStatus == 'in_production',
                )
                .toList();
        _readyOrders =
            orders.where((o) => o.productionStatus == 'ready').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading orders: $e')));
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

      // Mark the created batch as queued so it appears in the active production queue.
      try {
        final supa = SupabaseService();
        final nowIso = DateTime.now().toIso8601String();
        // Attempt to write queued_at and position. Use updateProductionBatch which
        // accepts the batch id as string and a map of updates.
        await supa.updateProductionBatch(createdBatch.id.toString(), {
          'queued_at': nowIso,
          'position': 0,
        });
      } catch (e) {
        debugPrint('Failed to mark batch as queued: $e');
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
    // Confirm before shipping
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Shipment'),
            content: Text(
              'Are you sure you want to ship order ${order.orderNumber}?\n\nThis will move it to history and cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text('Ship Now'),
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

      // Update order to shipped status with dispatch_date set
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
      bool finalSuccess = success;

      // If direct update failed (often due to schema mismatch on the server),
      // try a safer RPC that updates the order and associated batches server-side.
      if (!success) {
        try {
          final supa = SupabaseService();
          final rpcOk = await supa.shipOrderAndBatchesRpc(
            order.id!,
            status: 'dispatched',
            shippedAt: DateTime.parse(dispatchDate),
          );
          finalSuccess = rpcOk;
        } catch (e) {
          debugPrint('RPC fallback failed: $e');
        }
      }

      if (finalSuccess && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Order shipped successfully')));
        // Archive related production batch into production_queue_history and remove
        // it from production_batches so it no longer appears in the active queue.
        try {
          final supa = SupabaseService();
          final batchService = ProductionBatchOrderService();
          final batch = await batchService.getByOrderId(order.id!);
          if (batch != null && batch.id != null) {
            await supa.archiveBatchAndRemoveFromQueue(batch.id!, {
              'status': 'shipped',
              'progress': 100,
              'shipped_at': dispatchDate,
              'notes': 'Shipped from DispatchPage',
            });
          }
        } catch (e) {
          debugPrint('Error archiving production batch for shipped order: $e');
        }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch Management'),
        leading: BackToDashboardButton(),
        backgroundColor: Colors.indigo[700],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      color: Colors.indigo[50],
                      child: const TabBar(
                        indicatorColor: Colors.indigo,
                        labelColor: Colors.indigo,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(icon: Icon(Icons.build), text: 'In Production'),
                          Tab(icon: Icon(Icons.check_circle), text: 'Ready'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // In Production Tab
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child:
                                _inProductionOrders.isEmpty
                                    ? Center(
                                      child: Text(
                                        'No orders in production',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: _inProductionOrders.length,
                                      itemBuilder:
                                          (context, idx) => _buildOrderCard(
                                            _inProductionOrders[idx],
                                            isProduction: true,
                                          ),
                                    ),
                          ),
                          // Ready Tab
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child:
                                _readyOrders.isEmpty
                                    ? Center(
                                      child: Text(
                                        'No orders ready',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: _readyOrders.length,
                                      itemBuilder:
                                          (context, idx) => _buildOrderCard(
                                            _readyOrders[idx],
                                            isProduction: false,
                                          ),
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

  Widget _buildOrderCard(Order order, {required bool isProduction}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isProduction ? Colors.orange[50] : Colors.green[50],
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(order.orderNumber ?? 'Order #${order.id}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client: ${order.clientName ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<OrderItem>>(
                        future: OrdersService.instance.getOrderItemsForOrder(
                          order.id!,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text(
                              'Products: Loading...',
                              style: TextStyle(color: Colors.grey),
                            );
                          }
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return const Text(
                              'Products: None',
                              style: TextStyle(color: Colors.grey),
                            );
                          }
                          return Text(
                            'Products: ${items.map((i) => '${i.productName ?? ''} (Qty: ${i.quantity ?? ''})').join(', ')}',
                            style: const TextStyle(color: Colors.grey),
                          );
                        },
                      ),
                      Text('Due Date: ${order.dueDate}'),
                      if (order.dispatchDate != null)
                        Text('Dispatch Date: ${order.dispatchDate}'),
                      Text(
                        'Total: \u20b9${order.totalAmount.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isProduction ? Icons.build : Icons.check_circle,
                    color:
                        isProduction ? Colors.orange[700] : Colors.green[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.orderNumber ?? 'Order #${order.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                order.clientName ?? 'N/A',
                style: const TextStyle(fontSize: 15),
              ),
              FutureBuilder<List<OrderItem>>(
                future: OrdersService.instance.getOrderItemsForOrder(order.id!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text(
                      'Products: Loading...',
                      style: TextStyle(color: Colors.grey),
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Text(
                      'Products: None',
                      style: TextStyle(color: Colors.grey),
                    );
                  }
                  return Text(
                    'Products: ${items.map((i) => '${i.productName ?? ''} (Qty: ${i.quantity ?? ''})').join(', ')}',
                    style: const TextStyle(color: Colors.grey),
                  );
                },
              ),
              Text('Due Date: ${order.dueDate}'),
              if (order.dispatchDate != null)
                Text('Dispatch Date: ${order.dispatchDate}'),
              Text('Total: \u20b9${order.totalAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (isProduction)
                    Tooltip(
                      message: 'Move order to Ready',
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Move to Ready'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showMoveToReadyDialog(order),
                      ),
                    )
                  else
                    Tooltip(
                      message: 'Ship this order',
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.local_shipping),
                        label: const Text('Ship Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _shipOrder(order),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
