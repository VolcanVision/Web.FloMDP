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
              'Dispatch Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage production batches',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: Colors.blue.shade300,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      labelColor: Colors.blue.shade900,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      tabs: const [
                        Tab(text: 'In Production'),
                        Tab(text: 'Ready for Dispatch'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // In Production Tab
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _inProductionOrders.isEmpty
                              ? _buildEmptyState('No orders in production', Icons.build_circle_outlined)
                              : ListView.separated(
                                  itemCount: _inProductionOrders.length,
                                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) => _buildOrderCard(
                                    _inProductionOrders[idx],
                                    isProduction: true,
                                  ),
                                ),
                        ),
                        // Ready Tab
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _readyOrders.isEmpty
                              ? _buildEmptyState('No orders ready', Icons.check_circle_outline)
                              : ListView.separated(
                                  itemCount: _readyOrders.length,
                                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                                  itemBuilder: (context, idx) => _buildOrderCard(
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, {required bool isProduction}) {
    final statusColor = isProduction ? Colors.orange : Colors.green;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Colored left strip
            Container(
              width: 5,
              color: statusColor,
            ),
            // Main content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.03),
                ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Keep existing dialog logic but maybe style it later? 
          // For now, focusing on the card UI as requested.
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(order.orderNumber ?? 'Order #${order.id}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Client: ${order.clientName ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  FutureBuilder<List<OrderItem>>(
                    future: OrdersService.instance.getOrderItemsForOrder(order.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Text('Loading products...');
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) return const Text('No products');
                      return Text('Products: ${items.map((i) => '${i.productName} (${i.quantity})').join(', ')}');
                    },
                  ),
                  const SizedBox(height: 6),
                  Text('Due Date: ${order.dueDate}'),
                  if (order.dispatchDate != null) Text('Dispatch Date: ${order.dispatchDate}'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          );
        },
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isProduction ? Icons.build : Icons.check_circle,
                      color: statusColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber ?? 'Order #${order.id}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blueGrey[800],
                          ),
                        ),
                        Text(
                          order.clientName ?? 'Unknown Client',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isProduction)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        'In Production',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                ],
              ),
            ),
            
            // Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${_formatDate(order.dueDate)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      if (order.dispatchDate != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.local_shipping_outlined, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          'Dispatch: ${_formatDate(order.dispatchDate!)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Products Preview
                  FutureBuilder<List<OrderItem>>(
                    future: OrdersService.instance.getOrderItemsForOrder(order.id!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Container(
                          height: 20, 
                          width: 100, 
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                        );
                      }
                      final items = snapshot.data!;
                      if (items.isEmpty) return const Text('No products', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
                      
                      return Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: items.take(3).map((item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blueGrey[100]!),
                          ),
                          child: Text(
                            '${item.productName} (${item.quantity})',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                          ),
                        )).toList()
                          ..addAll(items.length > 3 ? [
                             Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text('+${items.length - 3} more', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            )
                          ] : []),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: isProduction
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Move to Ready'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showMoveToReadyDialog(order),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_empty, size: 18, color: Colors.orange.shade800),
                                const SizedBox(width: 8),
                                Text(
                                  'Waiting for Dispatch',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // InkWell
              ), // Container Bg
            ), // Expanded
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      // Simple formatter, or import intl. 
      // Using basic splits to match existing style if intl not available, but usually it is.
      // The file doesn't import intl but I can check.
      // Wait, I should check imports. 
      return '${d.day}/${d.month}/${d.year}';
    } catch (e) {
      return date;
    }
  }
}
