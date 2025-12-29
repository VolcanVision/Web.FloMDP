import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/shipment.dart';
import '../../services/orders_service.dart';
import '../../services/shipment_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/back_to_dashboard.dart';

class DispatchTrackingPage extends StatefulWidget {
  const DispatchTrackingPage({super.key});

  @override
  State<DispatchTrackingPage> createState() => _DispatchTrackingPageState();
}

class _DispatchTrackingPageState extends State<DispatchTrackingPage> with SingleTickerProviderStateMixin {
  final ShipmentService _shipmentService = ShipmentService();
  late TabController _tabController;
  
  List<Order> _readyOrders = [];
  List<_ShipmentWithOrder> _shippedOrders = [];
  List<_ShipmentWithOrder> _deliveredOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Fetch orders with productionStatus = 'ready' (no shipment yet)
      final allOrders = await OrdersService.instance.getOrders();
      final readyOrders = allOrders.where((o) => o.productionStatus == 'ready').toList();
      
      // Fetch shipped/in-transit shipments
      final shippedShipments = await _shipmentService.getByStatus('in_transit');
      final deliveredShipments = await _shipmentService.getByStatus('delivered');
      
      // Join shipments with order info
      final shippedWithOrders = <_ShipmentWithOrder>[];
      for (final s in shippedShipments) {
        final order = allOrders.firstWhere((o) => o.id == s.orderId, orElse: () => Order(dueDate: ''));
        if (order.id != null) {
          shippedWithOrders.add(_ShipmentWithOrder(shipment: s, order: order));
        }
      }
      
      final deliveredWithOrders = <_ShipmentWithOrder>[];
      for (final s in deliveredShipments) {
        final order = allOrders.firstWhere((o) => o.id == s.orderId, orElse: () => Order(dueDate: ''));
        if (order.id != null) {
          deliveredWithOrders.add(_ShipmentWithOrder(shipment: s, order: order));
        }
      }
      
      if (!mounted) return;
      setState(() {
        _readyOrders = readyOrders;
        _shippedOrders = shippedWithOrders;
        _deliveredOrders = deliveredWithOrders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showShipDialog(Order order) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final driverCtrl = TextEditingController();
    final inchargeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ship Order'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(nameCtrl, 'Shipment Name'),
              const SizedBox(height: 12),
              _buildField(inchargeCtrl, 'Shipment Incharge'),
              const SizedBox(height: 12),
              _buildField(companyCtrl, 'Shipping Company'),
              const SizedBox(height: 12),
              _buildField(vehicleCtrl, 'Vehicle Details'),
              const SizedBox(height: 12),
              _buildField(driverCtrl, 'Driver Contact'),
              const SizedBox(height: 12),
              _buildField(locationCtrl, 'Current Location'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _createShipment(order, nameCtrl.text, locationCtrl.text, companyCtrl.text, vehicleCtrl.text, driverCtrl.text, inchargeCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Ship', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createShipment(Order order, String name, String location, String company, String vehicle, String driver, String incharge) async {
    final shipment = Shipment(
      orderId: order.id!,
      shipmentName: name.isNotEmpty ? name : 'Shipment-${order.orderNumber}',
      shippedAt: DateTime.now().toIso8601String().split('T')[0],
      status: 'in_transit',
      shipmentIncharge: incharge.isNotEmpty ? incharge : null,
      shippingCompany: company.isNotEmpty ? company : null,
      vehicleDetails: vehicle.isNotEmpty ? vehicle : null,
      driverContactNumber: driver.isNotEmpty ? driver : null,
      location: location.isNotEmpty ? location : null,
    );

    final created = await _shipmentService.create(shipment);
    if (created != null) {
      
      // Update Inventory Quantities (Moved from Production Dispatch to Accounts Dispatch)
      try {
        final orderItems =
            await OrdersService.instance.getOrderItemsForOrder(order.id!);
        if (orderItems.isNotEmpty) {
          final inventoryItems = await SupabaseService().getInventoryItems();
          for (final item in orderItems) {
            final searchName = item.productName.trim().toLowerCase();
            try {
              final invItem = inventoryItems.firstWhere(
                (inv) => inv.name.trim().toLowerCase() == searchName,
              );
              // Reduce quantity
              double deductQty = item.quantity.toDouble();
              invItem.quantity -= deductQty;
              
              // Update inventory item in DB
              final invService = SupabaseService();
              await invService.updateInventoryItem(invItem);
              debugPrint('Reduced inventory for ${invItem.name} by $deductQty');
            } catch (e) {
              // inventory item not found or update failed
              debugPrint(
                'Inventory update skipped for ${item.productName}: $e',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing inventory updates: $e');
        // Continue with order status update even if inventory fails
      }

      // Update order status
      final updatedOrder = Order(
        id: order.id,
        orderNumber: order.orderNumber,
        clientName: order.clientName,
        advancePaid: order.advancePaid,
        dueDate: order.dueDate,
        dispatchDate: DateTime.now().toIso8601String().split('T')[0],
        isAdvancePaid: order.isAdvancePaid,
        afterDispatchDays: order.afterDispatchDays,
        orderStatus: 'dispatched',
        paymentStatus: order.paymentStatus,
        productionStatus: 'shipped',
        totalAmount: order.totalAmount,
      );
      await OrdersService.instance.updateOrder(updatedOrder);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order shipped!')));
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_shipmentService.lastError ?? 'Failed')));
    }
  }

  void _showUpdateLocationDialog(_ShipmentWithOrder item) {
    final locationCtrl = TextEditingController(text: item.shipment.location ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Location'),
        content: TextField(
          controller: locationCtrl,
          decoration: const InputDecoration(labelText: 'Current Location', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = Shipment(
                id: item.shipment.id,
                orderId: item.shipment.orderId,
                shipmentName: item.shipment.shipmentName,
                shippedAt: item.shipment.shippedAt,
                status: item.shipment.status,
                location: locationCtrl.text,
                shippingCompany: item.shipment.shippingCompany,
                vehicleDetails: item.shipment.vehicleDetails,
                driverContactNumber: item.shipment.driverContactNumber,
                shipmentIncharge: item.shipment.shipmentIncharge,
              );
              final ok = await _shipmentService.update(updated);
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location updated')));
                _loadData();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _markDelivered(_ShipmentWithOrder item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Delivered?'),
        content: Text('Mark shipment "${item.shipment.shipmentName}" as delivered?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Delivered', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _shipmentService.markDelivered(item.shipment.id!);
      if (ok) {
        // Update order status
        final updatedOrder = Order(
          id: item.order.id,
          orderNumber: item.order.orderNumber,
          clientName: item.order.clientName,
          advancePaid: item.order.advancePaid,
          dueDate: item.order.dueDate,
          dispatchDate: item.order.dispatchDate,
          isAdvancePaid: item.order.isAdvancePaid,
          afterDispatchDays: item.order.afterDispatchDays,
          orderStatus: 'completed',
          paymentStatus: item.order.paymentStatus,
          productionStatus: 'delivered',
          totalAmount: item.order.totalAmount,
        );
        await OrdersService.instance.updateOrder(updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as delivered')));
        _loadData();
      }
    }
  }

  Future<void> _undoDelivered(_ShipmentWithOrder item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Delivery?'),
        content: Text('Move "${item.shipment.shipmentName}" back to In-Transit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Undo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _shipmentService.undoDelivered(item.shipment.id!);
      if (ok) {
        // Revert order status
        final updatedOrder = Order(
          id: item.order.id,
          orderNumber: item.order.orderNumber,
          clientName: item.order.clientName,
          advancePaid: item.order.advancePaid,
          dueDate: item.order.dueDate,
          dispatchDate: item.order.dispatchDate,
          isAdvancePaid: item.order.isAdvancePaid,
          afterDispatchDays: item.order.afterDispatchDays,
          orderStatus: 'dispatched',
          paymentStatus: item.order.paymentStatus,
          productionStatus: 'shipped',
          totalAmount: item.order.totalAmount,
        );
        await OrdersService.instance.updateOrder(updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved back to In-Transit')));
        _loadData();
      }
    }
  }

  void _showShipmentDetails(_ShipmentWithOrder item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.shipment.shipmentName ?? 'Shipment'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Order', item.order.orderNumber ?? '#${item.order.id}'),
              _detailRow('Client', item.order.clientName ?? 'N/A'),
              _detailRow('Status', item.shipment.status.toUpperCase()),
              const Divider(),
              _detailRow('Shipping Company', item.shipment.shippingCompany ?? '-'),
              _detailRow('Vehicle', item.shipment.vehicleDetails ?? '-'),
              _detailRow('Driver Contact', item.shipment.driverContactNumber ?? '-'),
              _detailRow('Incharge', item.shipment.shipmentIncharge ?? '-'),
              const Divider(),
              _detailRow('Location', item.shipment.location ?? '-'),
              _detailRow('Shipped At', item.shipment.shippedAt),
              if (item.shipment.deliveredAt != null)
                _detailRow('Delivered At', item.shipment.deliveredAt!.toIso8601String().split('T')[0]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showDeliveredHistoryDialog(_ShipmentWithOrder item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivered Order',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            item.order.orderNumber ?? '#${item.order.id}',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Info Section
                      _buildSectionHeader('Order Information'),
                      _historyDetailRow('Client', item.order.clientName ?? 'N/A'),
                      _historyDetailRow('Order Number', item.order.orderNumber ?? '#${item.order.id}'),
                      _historyDetailRow('Due Date', item.order.dueDate),
                      if (item.order.totalAmount != null && item.order.totalAmount! > 0)
                        _historyDetailRow('Total Amount', '₹${item.order.totalAmount!.toStringAsFixed(2)}'),
                      if (item.order.advancePaid != null && item.order.advancePaid! > 0)
                        _historyDetailRow('Advance Paid', '₹${item.order.advancePaid!.toStringAsFixed(2)}'),
                      if (item.order.totalAmount != null && item.order.advancePaid != null)
                        _historyDetailRow(
                          'Pending Amount',
                          '₹${(item.order.totalAmount! - item.order.advancePaid!).toStringAsFixed(2)}',
                          valueColor: Colors.orange.shade700,
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Shipment Info Section
                      _buildSectionHeader('Shipment Details'),
                      _historyDetailRow('Shipped Date', item.shipment.shippedAt),
                      if (item.shipment.deliveredAt != null)
                        _historyDetailRow(
                          'Delivered Date',
                          item.shipment.deliveredAt!.toIso8601String().split('T')[0],
                          valueColor: Colors.green.shade700,
                        ),
                      _historyDetailRow('Shipping Company', item.shipment.shippingCompany ?? '-'),
                      _historyDetailRow('Vehicle', item.shipment.vehicleDetails ?? '-'),
                      _historyDetailRow('Driver Contact', item.shipment.driverContactNumber ?? '-'),
                      _historyDetailRow('Incharge', item.shipment.shipmentIncharge ?? '-'),
                      if (item.shipment.location != null && item.shipment.location!.isNotEmpty)
                        _historyDetailRow('Last Location', item.shipment.location!),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _undoDelivered(item);
                      },
                      icon: Icon(Icons.undo, size: 16, color: Colors.orange.shade600),
                      label: Text('Undo Delivery', style: TextStyle(color: Colors.orange.shade600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.orange.shade300),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Close'),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _historyDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    );
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
              'Dispatch Tracking',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitor shipments in real-time',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.pending_actions),
              text: 'Ready (${_readyOrders.length})',
            ),
            Tab(
              icon: const Icon(Icons.local_shipping),
              text: 'In Transit (${_shippedOrders.length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle),
              text: 'Delivered (${_deliveredOrders.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFullPageColumn('Ready for Dispatch', Colors.orange, _readyOrders, isReady: true),
                  _buildFullPageColumn('In Transit', Colors.blue, _shippedOrders),
                  _buildFullPageColumn('Delivered', Colors.green, _deliveredOrders, isDelivered: true),
                ],
              ),
            ),
    );
  }

  Widget _buildFullPageColumn(String title, Color color, List items, {bool isReady = false, bool isDelivered = false}) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            border: Border(bottom: BorderSide(color: color.withAlpha(50))),
          ),
          child: Row(
            children: [
              Icon(
                isReady ? Icons.pending_actions : isDelivered ? Icons.check_circle : Icons.local_shipping,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isReady ? Icons.inbox : isDelivered ? Icons.move_to_inbox : Icons.local_shipping_outlined,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text('No items', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(
                        isReady ? 'Orders ready for dispatch will appear here' : 
                        isDelivered ? 'Delivered shipments will appear here' : 
                        'Shipments in transit will appear here',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (ctx, idx) {
                    if (isReady) {
                      final order = items[idx] as Order;
                      return _buildReadyCard(order, color);
                    } else {
                      final shipmentItem = items[idx] as _ShipmentWithOrder;
                      return _buildShipmentCard(shipmentItem, color, isDelivered: isDelivered);
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReadyCard(Order order, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: Colors.orange.shade400, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.pending_actions, color: Colors.orange.shade600, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber ?? '#${order.id}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          order.clientName ?? 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${order.dueDate}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  if (order.location != null && order.location!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        order.location!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => _showShipDialog(order),
                  icon: const Icon(Icons.local_shipping, size: 16),
                  label: const Text('Ship Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShipmentCard(_ShipmentWithOrder item, Color color, {bool isDelivered = false}) {
    final baseColor = isDelivered ? Colors.green : Colors.blue;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: baseColor.shade100),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: baseColor.shade400, width: 3),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => isDelivered ? _showDeliveredHistoryDialog(item) : _showShipmentDetails(item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: baseColor.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDelivered ? Icons.check_circle : Icons.local_shipping,
                          color: baseColor.shade600,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.shipment.shipmentName ?? 'Shipment',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              item.order.clientName ?? 'N/A',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: baseColor.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isDelivered ? 'Delivered' : 'In Transit',
                          style: TextStyle(
                            fontSize: 10,
                            color: baseColor.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.receipt_long, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'Order: ${item.order.orderNumber ?? '#${item.order.id}'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                      const Spacer(),
                      Icon(Icons.calendar_today, size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        item.shipment.shippedAt,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                      ),
                    ],
                  ),
                  if (item.shipment.location != null && item.shipment.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: baseColor.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.shipment.location!,
                            style: TextStyle(color: baseColor.shade600, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (!isDelivered)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: OutlinedButton.icon(
                              onPressed: () => _showUpdateLocationDialog(item),
                              icon: Icon(Icons.edit_location_alt, size: 14, color: baseColor.shade600),
                              label: Text('Update', style: TextStyle(fontSize: 11, color: baseColor.shade600)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: baseColor.shade300),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: () => _markDelivered(item),
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Delivered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade500,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.shipment.deliveredAt != null
                                ? 'Delivered on ${item.shipment.deliveredAt!.toIso8601String().split('T')[0]}'
                                : 'Delivered',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _undoDelivered(item),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 28),
                          ),
                          child: Text('Undo', style: TextStyle(color: Colors.orange.shade600, fontSize: 11)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShipmentWithOrder {
  final Shipment shipment;
  final Order order;
  _ShipmentWithOrder({required this.shipment, required this.order});
}
