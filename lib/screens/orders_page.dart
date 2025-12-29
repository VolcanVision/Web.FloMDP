import 'package:flutter/material.dart';
import '../models/advance_payment.dart';
import '../services/advance_payments_service.dart';
import '../services/excel_export_service.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/orders_service.dart';
import '../models/shipment.dart';
import '../services/shipment_service.dart';
import '../theme/pastel_colors.dart';
import '../widgets/back_to_dashboard.dart';

/// Clean, minimal Orders page that shows the orders list by default and
/// provides a glossy FloatingActionButton to add new orders via a dialog.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final Map<int, double> _advanceCache = {};
  final Map<int, Shipment> _shipmentMap = {};
  // status filter removed per user request
  List<Order> orders = [];
  List<Order> filteredOrders = [];
  final TextEditingController _searchController = TextEditingController();
  
  // Sort options
  String _sortBy = 'date_desc'; // 'name_asc', 'name_desc', 'date_asc', 'date_desc'

  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _totalController = TextEditingController();
  final _advanceController = TextEditingController();
  final _dueController = TextEditingController();
  final _afterDispatchController = TextEditingController();
  final _finalDueDateController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isAdvancePaid = false;

  // Product list for the current order
  final List<Map<String, dynamic>> _currentProducts = [];
  // Index of product being edited in the add-product row. Null when not editing.
  int? _editingProductIndex;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadOrders() async {
    try {
      orders = await OrdersService.instance.getOrders();
      // Sort by date (newest first) and then by client name
      orders.sort((a, b) {
        // First compare by date (descending)
        final dateA = a.createdAt ?? DateTime(0);
        final dateB = b.createdAt ?? DateTime(0);
        int dateComp = dateB.compareTo(dateA);
        if (dateComp != 0) return dateComp;

        return (a.clientName ?? '').toLowerCase().compareTo((b.clientName ?? '').toLowerCase());
      });
      _advanceCache.clear();
      _shipmentMap.clear();

      try {
        final allShipments = await ShipmentService().getAllShipments();
        for (final s in allShipments) {
          // If multiple shipments for same order, prefer latest (shipped_at desc in query)
          if (!_shipmentMap.containsKey(s.orderId)) {
            _shipmentMap[s.orderId] = s;
          }
        }
      } catch (e) {
        debugPrint('Error loading shipments: $e');
      }

      for (final order in orders) {
        if (order.id != null) {
          _advanceCache[order.id!] = await AdvancePaymentsService.instance
              .getTotalAdvancePaid(order.id!);
        }
      }
      filteredOrders = orders;
      _searchController.text = '';
      _onSearchChanged();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading orders: $e')));
    }
  }

  /// Export all orders to Excel/CSV
  Future<void> _exportAllOrdersToExcel() async {
    try {
      final headers = [
        'Order No.',
        'Client Name',
        'Products & Quantity',
        'Expected Dispatch Date',
        'Dispatch Date',
        'Total Amount',
        'Total Installments Paid',
        'Pending Amount',
        'Batch No.',
        'Batch Details',
        'Shipment Details',
        'Vehicle Number',
        'Location',
        'Order Status',
        'Payment Status',
        'Production Status',
      ];

      final List<List<dynamic>> rows = [];
      for (final order in filteredOrders) {
        // Get order items for products list
        final orderItems = await OrdersService.instance.getOrderItemsForOrder(order.id!);
        final productsStr = orderItems.map((item) => '${item.productName} x ${item.quantity}').join(', ');
        
        // Get total installments paid
        final totalPaid = _advanceCache[order.id] ?? 0.0;
        
        rows.add([
          order.orderNumber ?? '',
          order.clientName ?? '',
          productsStr,
          order.dueDate,
          order.dispatchDate ?? '',
          order.totalAmount.toStringAsFixed(2),
          totalPaid.toStringAsFixed(2),
          (order.totalAmount - totalPaid).toStringAsFixed(2),
          '', // Batch No - from shipment if available
          '', // Batch Details
          '', // Shipment Details
          '', // Vehicle Number
          order.location ?? '',
          order.orderStatus,
          order.paymentStatus,
          order.productionStatus,
        ]);
      }

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: 'orders_export_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Orders exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Export a single order to Excel/CSV
  Future<void> _exportSingleOrderToExcel(Order order) async {
    try {
      final orderItems = await OrdersService.instance.getOrderItemsForOrder(order.id!);
      final totalPaid = _advanceCache[order.id] ?? 0.0;
      final installments = await AdvancePaymentsService.instance.getPaymentsForOrder(order.id!);

      final headers = [
        'Field',
        'Value',
      ];

      final rows = <List<dynamic>>[
        ['Order Number', order.orderNumber ?? ''],
        ['Client Name', order.clientName ?? ''],
        ['Location', order.location ?? ''],
        ['Expected Dispatch Date', order.dueDate],
        ['Dispatch Date', order.dispatchDate ?? ''],
        ['Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}'],
        ['Total Paid', '₹${totalPaid.toStringAsFixed(2)}'],
        ['Pending Amount', '₹${(order.totalAmount - totalPaid).toStringAsFixed(2)}'],
        ['Order Status', order.orderStatus],
        ['Payment Status', order.paymentStatus],
        ['Production Status', order.productionStatus],
        ['', ''], // Empty row
        ['Products', ''],
      ];

      // Add products
      for (final item in orderItems) {
        rows.add(['  ${item.productName}', 'Qty: ${item.quantity}']);
      }

      rows.add(['', '']); // Empty row
      rows.add(['Installments', '']);
      
      // Add installments
      for (final payment in installments) {
        final dateStr = payment.paidAt.isNotEmpty
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(payment.paidAt))
            : '';
        rows.add(['  $dateStr', '₹${payment.amount.toStringAsFixed(2)}']);
      }

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: 'order_${order.orderNumber ?? order.id}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _showAddOrderDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                radius: 24,
                                child: Icon(
                                  Icons.add_shopping_cart,
                                  color: Colors.blue.shade700,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create New Order',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 19,
                                        color: Colors.blue[900],
                                      ),
                                    ),

                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.blueGrey[400],
                                ),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                          const Divider(height: 28, thickness: 1.2),
                          _buildModernTextField(
                            controller: _clientNameController,
                            label: 'Client Name',
                            icon: Icons.person,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader('Products'),
                          const SizedBox(height: 10),
                          _buildProductAdditionRow((fn) => setState(fn)),
                          const SizedBox(height: 20),
                          _buildSectionHeader('Dates'),
                          const SizedBox(height: 10),
                          _buildDateFields((fn) => setState(fn)),
                          const SizedBox(height: 20),
                          _buildSectionHeader('Payment'),
                          const SizedBox(height: 10),
                          _buildAdvancePaymentSection((fn) => setState(fn)),
                          const SizedBox(height: 24),
                          _buildActionButtons(ctx),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdvancePaymentSection(StateSetter setDialogState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildModernTextField(
            controller: _totalController,
            label: 'Total Amount',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
            validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null) ? 'Invalid' : null,
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _afterDispatchController,
            label: 'After Dispatch Days',
            icon: Icons.schedule,
            keyboardType: TextInputType.number,
            validator: (v) => (v != null && v.isNotEmpty && int.tryParse(v) == null) ? 'Invalid' : null,
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _finalDueDateController,
            label: 'Final Payment Date (optional)',
            icon: Icons.event,
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                _finalDueDateController.text = picked.toIso8601String().split('T')[0];
                setDialogState(() {});
              }
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          CheckboxListTile(
            value: _isAdvancePaid,
            onChanged: (v) => setDialogState(() => _isAdvancePaid = v ?? false),
            title: const Text('Installment Received'),
            subtitle: const Text('Check if client has made an initial payment'),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.blue.shade600,
            contentPadding: EdgeInsets.zero,
          ),
          if (_isAdvancePaid) ...[
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _advanceController,
              label: 'Installment Amount',
              icon: Icons.payment,
              keyboardType: TextInputType.number,
              validator: (v) => (v != null && v.isNotEmpty && double.tryParse(v) == null) ? 'Invalid' : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateFields(StateSetter setDialogState) {
    return Column(
      children: [
        _buildModernTextField(
          controller: _dueController,
          label: 'Expected Dispatch Date',
          icon: Icons.calendar_today,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              _dueController.text = picked.toIso8601String().split('T')[0];
              setDialogState(() {});
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext ctx) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () async {
              await _createOrder(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_shopping_cart, size: 20),
                SizedBox(width: 8),
                Text(
                  'Create Order',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createOrder(BuildContext ctx) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_currentProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    try {
      // Parse common fields
      final advancePaid =
          _advanceController.text.isEmpty
              ? 0.0
              : double.parse(_advanceController.text);

      // due date is required by model
      String dueDateStr = _dueController.text.trim();
      DateTime dueDate;
      try {
        dueDate = DateTime.parse(dueDateStr);
      } catch (_) {
        dueDate = DateTime.now();
        dueDateStr = dueDate.toIso8601String();
      }

      // compute final due date if afterDispatchDays provided
      String? finalDue;
      if (_finalDueDateController.text.trim().isNotEmpty) {
        finalDue = _finalDueDateController.text.trim();
      } else if (_afterDispatchController.text.trim().isNotEmpty &&
          int.tryParse(_afterDispatchController.text) != null) {
        finalDue =
            dueDate
                .add(Duration(days: int.parse(_afterDispatchController.text)))
                .toIso8601String();
      }

      // Use total amount from field
      double totalAmount = 0.0;
      if (_totalController.text.isNotEmpty &&
          double.tryParse(_totalController.text) != null) {
        totalAmount = double.parse(_totalController.text);
      }

      // Create the order for the client
      final newOrder = Order(
        clientName: _clientNameController.text.trim(),
        advancePaid: advancePaid,
        dueDate: dueDateStr,
        isAdvancePaid: _isAdvancePaid,
        afterDispatchDays:
            _afterDispatchController.text.isEmpty
                ? 0
                : int.parse(_afterDispatchController.text),
        finalDueDate: finalDue,
        finalPaymentDate: finalDue,
        totalAmount: totalAmount,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      );

      // Create the order and the items in one call so we don't accidentally
      // create duplicate orders. OrdersService.addOrder will insert order_items
      // when `products` is provided.
      await OrdersService.instance.addOrder(
        newOrder,
        products: _currentProducts,
      );

      if (!mounted) return;

      Navigator.of(ctx).pop();
      _clientNameController.clear();
      _productController.clear();
      _quantityController.clear();
      _totalController.clear();
      _advanceController.clear();
      _dueController.clear();
      _afterDispatchController.clear();
      _finalDueDateController.clear();
      _locationController.clear();
      _isAdvancePaid = false;
      _currentProducts.clear();

      await _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildOrderTile(Order o) {
    return FutureBuilder<List<OrderItem>>(
      future: OrdersService.instance.getOrderItemsForOrder(o.id!),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        return FutureBuilder<double>(
          future: AdvancePaymentsService.instance.getTotalAdvancePaid(o.id!),
          builder: (context, snap2) {
            final totalAdvance = snap2.data ?? 0.0;
            final pendingAmount = o.totalAmount - totalAdvance;
            final isPaid = pendingAmount <= 0.0;
            final isPartial = !isPaid && totalAdvance > 0.0;
            final statusColor =
                isPaid
                    ? Colors.green
                    : (isPartial ? Colors.orange : Colors.red);

            final shipment = _shipmentMap[o.id];
            final displayStatus = shipment?.status ?? o.orderStatus;
            final displayLocation = (shipment != null &&
                        shipment.location != null &&
                        shipment.location!.isNotEmpty)
                    ? shipment.location
                    : o.location;

            return InkWell(
              onTap: () => _showOrderDetailsDialog(o),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${o.clientName ?? 'Client'}  •  #${o.orderNumber ?? o.id}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blueGrey[900],
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (displayLocation != null && displayLocation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    displayLocation,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),
                        if (items.isEmpty)
                          Text('No products', style: TextStyle(fontSize: 12, color: Colors.grey[400]))
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: items.map((i) {
                              return SizedBox(
                                width: 140,
                                child: Row(
                                  children: [
                                    Icon(Icons.trip_origin, size: 8, color: Colors.blue.shade200),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${i.productName} (x${i.quantity})',
                                        style: TextStyle(fontSize: 11, color: Colors.blueGrey[700]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildMiniTag(
                              displayStatus.toUpperCase().replaceAll('_', ' '),
                              _getStatusColor(displayStatus).withOpacity(0.1),
                              _getStatusColor(displayStatus),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CustomPaint(painter: _TrianglePainter(statusColor)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _showOrderDetailsDialog(Order order) async {
    List<AdvancePayment> installments = await AdvancePaymentsService.instance
        .getPaymentsForOrder(order.id!);
    List<OrderItem> orderItems = await OrdersService.instance
        .getOrderItemsForOrder(order.id!);
    showDialog(
      context: context,
      builder: (ctx3) {
        final amountCtrl = TextEditingController();
        final editProdCtrl = TextEditingController();
        final editQtyCtrl = TextEditingController();
        DateTime? selectedDate;
        int? editingIndex;
        return StatefulBuilder(
          builder: (ctx3, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            radius: 24,
                            child: Icon(
                              Icons.shopping_cart,
                              color: Colors.blue.shade700,
                              size: 26,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.clientName ?? 'Edit Order',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 19,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                if (order.orderNumber != null)
                                  Text(
                                    '#${order.orderNumber}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blueGrey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.download,
                              color: Colors.blue.shade600,
                            ),
                            onPressed: () => _exportSingleOrderToExcel(order),
                            tooltip: 'Download Order',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.blueGrey[400],
                            ),
                            onPressed: () => Navigator.of(ctx3).pop(),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      
                      // Show Approve button if order is pending approval
                      if (order.orderStatus == 'pending_approval') ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 20, color: Colors.orange.shade800),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Review Required',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'This order is pending approval. Review the details below and approve to proceed with production.',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // Update status to new
                                    final updated = order.copyWith(orderStatus: 'new');
                                    final success = await OrdersService.instance.updateOrder(updated);
                                    
                                    if (mounted) {
                                      Navigator.pop(ctx3);
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Order approved successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _loadOrders();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to approve order'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle, color: Colors.white),
                                  label: const Text('Approve Order'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (order.orderStatus == 'new') ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 20, color: Colors.blue.shade800),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Order Approved',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'This order needs to be verified before production starts. If you approved this by mistake, you can undo it.',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    // Update status back to pending_approval
                                    final updated = order.copyWith(orderStatus: 'pending_approval');
                                    final success = await OrdersService.instance.updateOrder(updated);
                                    
                                    if (mounted) {
                                      Navigator.pop(ctx3);
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Approval undone'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        _loadOrders();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to undo approval'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.undo),
                                  label: const Text('Undo Approval'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Divider(height: 28, thickness: 1.2),
                      Text(
                        'Products',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Product list: each product on its own line with Qty and actions
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child:
                            orderItems.isEmpty
                                ? Text(
                                  'No products',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[800],
                                  ),
                                )
                                : Column(
                                  children:
                                      orderItems.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final it = entry.value;
                                        // Default display row
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${it.productName}  —  Qty: ${it.quantity}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.blueGrey[800],
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  color: Colors.blue.shade600,
                                                ),
                                                onPressed: () {
                                                  // populate editors and set editing index; editor will appear below list
                                                  editProdCtrl.text =
                                                      it.productName;
                                                  editQtyCtrl.text =
                                                      it.quantity.toString();
                                                  setState(() {
                                                    editingIndex = idx;
                                                  });
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.red.shade400,
                                                ),
                                                onPressed: () async {
                                                  // delete the order item
                                                  if (it.id != null) {
                                                    final ok =
                                                        await OrdersService
                                                            .instance
                                                            .deleteOrderItem(
                                                              it.id!,
                                                            );
                                                    if (!ok) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Failed to delete item',
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                  }
                                                  setState(() {
                                                    orderItems.removeAt(idx);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                      ),

                      // Editor area (appears below product list)
                      if (editingIndex != null) ...[
                        const SizedBox(height: 8),
                        _buildModernTextField(
                          controller: editProdCtrl,
                          label: 'Product',
                          icon: Icons.inventory_2,
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                        ),
                        const SizedBox(height: 8),
                        // Quantity field full-width so the text is visible
                        _buildModernTextField(
                          controller: editQtyCtrl,
                          label: 'Qty',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                          fillColor: Colors.blue.shade50,
                          textColor: Colors.blueGrey[900],
                          validator:
                              (v) =>
                                  (v != null &&
                                          v.isNotEmpty &&
                                          int.tryParse(v) == null)
                                      ? 'Invalid'
                                      : null,
                        ),
                        const SizedBox(height: 8),
                        // Compact action row beneath the qty field with smaller icons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.save, size: 16),
                              label: Text(
                                'Save',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                padding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
                                minimumSize: Size(64, 36),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final prodName = editProdCtrl.text.trim();
                                final qty =
                                    int.tryParse(editQtyCtrl.text.trim()) ?? 0;
                                if (prodName.isEmpty) return;
                                final orig = orderItems[editingIndex!];
                                final updated = OrderItem(
                                  id: orig.id,
                                  orderId: orig.orderId,
                                  productName: prodName,
                                  quantity: qty,
                                  note: orig.note,
                                  createdAt: orig.createdAt,
                                );
                                bool ok = true;
                                if (updated.id != null) {
                                  ok = await OrdersService.instance
                                      .updateOrderItem(updated);
                                }
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to save item'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  orderItems[editingIndex!] = updated;
                                  editingIndex = null;
                                  editProdCtrl.clear();
                                  editQtyCtrl.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.grey,
                              ),
                              label: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
                                minimumSize: Size(64, 36),
                                side: BorderSide(color: Colors.grey.shade200),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setState(() {
                                  editingIndex = null;
                                  editProdCtrl.clear();
                                  editQtyCtrl.clear();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      const Divider(height: 32),
                      Text(
                        'Payments',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Builder(builder: (context) {
                        final totalPaid = installments.fold<double>(0, (sum, i) => sum + i.amount);
                        final pending = order.totalAmount - totalPaid;
                        Color statusColor = pending <= 1.0 ? Colors.green : (totalPaid > 0 ? Colors.orange : Colors.red);
                        String statusText = pending <= 1.0 ? 'PAID' : (totalPaid > 0 ? 'PARTIALLY PAID' : 'UNPAID');
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}'),
                            _buildDetailRow('Advance Paid', '₹${totalPaid.toStringAsFixed(2)}'),
                            _buildDetailRow('Pending Amount', '₹${pending.toStringAsFixed(2)}', valueColor: pending > 1.0 ? Colors.red : Colors.green),
                            _buildDetailRow('Payment Status', statusText, valueColor: statusColor),
                            
                            const SizedBox(height: 24),
                            Text(
                              'Installments',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Timeline details included under Installments section as requested
                            _buildDetailRow('Order Created', order.createdAt != null ? DateFormat('MMM dd, yyyy').format(order.createdAt!) : 'N/A'),
                            _buildDetailRow('Last Updated', order.updatedAt != null ? DateFormat('MMM dd, yyyy').format(order.updatedAt!) : 'N/A'),
                            _buildDetailRow('Expected Dispatch', _formatDateString(order.dueDate)),
                            _buildDetailRow('Final Payment Due', _formatDateString(order.finalPaymentDate)),
                            _buildDetailRow('Dispatch Date', order.dispatchDate ?? 'In Production'),
                            
                            const SizedBox(height: 16),
                            if (installments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No installment records found.', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic)),
                              )
                            else
                              ...installments.map((inst) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade100),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(DateTime.parse(inst.paidAt)),
                                      style: TextStyle(color: Colors.blueGrey[700], fontSize: 13),
                                    ),
                                    Text(
                                      '₹${inst.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )),

                            const SizedBox(height: 16),
                            // Add new installment inputs at the end of the section
                            if (pending > 1.0)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add Installment',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        TextField(
                                          controller: amountCtrl,
                                          decoration: InputDecoration(
                                            hintText: 'Amount',
                                            prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                                            filled: true,
                                            fillColor: Colors.white,
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.blue.shade200),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.blue.shade100),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: ctx3,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              selectedDate = picked;
                                              setState(() {});
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blue.shade100),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade600),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      selectedDate == null
                                                          ? 'Select Date'
                                                          : DateFormat('MM/dd/yy').format(selectedDate!),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: selectedDate == null ? Colors.grey : Colors.grey.shade800,
                                                        fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Icon(Icons.arrow_drop_down, color: Colors.blue.shade300),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              final amt = double.tryParse(amountCtrl.text);
                                              if (amt != null && selectedDate != null) {
                                                if (amt > pending + 1.0) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Installment exceeds pending amount!'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                  return;
                                                }

                                                final payment = AdvancePayment(
                                                  orderId: order.id!,
                                                  amount: amt,
                                                  paidAt: DateFormat('yyyy-MM-dd').format(selectedDate!),
                                                );
                                                await AdvancePaymentsService.instance.addPayment(payment);
                                                installments = await AdvancePaymentsService.instance.getPaymentsForOrder(order.id!);
                                                amountCtrl.clear();
                                                selectedDate = null;
                                                setState(() {});
                                                // also reload main list to update colors there
                                                _loadOrders();
                                              }
                                            },
                                            icon: const Icon(Icons.add, color: Colors.white),
                                            label: const Text('Add Installment'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue.shade600,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      }),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Order'),
                                  content: const Text('Permanently remove this order?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await OrdersService.instance.deleteOrder(order.id!);
                                Navigator.pop(ctx3);
                                _loadOrders();
                              }
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text('Delete Order', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
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
              'Orders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage customer orders',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download All Orders (Excel)',
            onPressed: _exportAllOrdersToExcel,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by client name...',
                        prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                        filled: true,
                        fillColor: Colors.blue.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.sort, color: Colors.blue.shade600),
                    tooltip: 'Sort',
                    onSelected: (value) {
                      setState(() {
                        _sortBy = value;
                        _sortOrders();
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'name_asc',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, size: 16, color: _sortBy == 'name_asc' ? Colors.blue : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Name A-Z', style: TextStyle(fontWeight: _sortBy == 'name_asc' ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'name_desc',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, size: 16, color: _sortBy == 'name_desc' ? Colors.blue : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Name Z-A', style: TextStyle(fontWeight: _sortBy == 'name_desc' ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'date_desc',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, size: 16, color: _sortBy == 'date_desc' ? Colors.blue : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Newest First', style: TextStyle(fontWeight: _sortBy == 'date_desc' ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'date_asc',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, size: 16, color: _sortBy == 'date_asc' ? Colors.blue : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Oldest First', style: TextStyle(fontWeight: _sortBy == 'date_asc' ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status filter removed - showing all orders (search by name only)
            Expanded(
              child:
                  filteredOrders.isEmpty
                      ? Center(
                        child: Text(
                          'No orders found.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: filteredOrders.length,
                        itemBuilder:
                            (ctx, idx) => _buildOrderTile(filteredOrders[idx]),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          onPressed: _showAddOrderDialog,
          backgroundColor: Colors.transparent,
          elevation: 6,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipOval(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.6, -0.6),
                          radius: 1.0,
                          colors: [
                            Colors.white.withOpacity(0.28),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.add, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clientNameController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _totalController.dispose();
    _advanceController.dispose();
    _dueController.dispose();
    _afterDispatchController.dispose();
    _finalDueDateController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredOrders = List.from(orders);
        _sortOrders();
      });
      return;
    }
    setState(() {
      filteredOrders =
          orders.where((order) {
            final clientName = order.clientName?.toLowerCase() ?? '';
            return clientName.contains(query);
          }).toList();
      _sortOrders();
    });
  }

  void _sortOrders() {
    switch (_sortBy) {
      case 'name_asc':
        filteredOrders.sort((a, b) => (a.clientName ?? '').toLowerCase().compareTo((b.clientName ?? '').toLowerCase()));
        break;
      case 'name_desc':
        filteredOrders.sort((a, b) => (b.clientName ?? '').toLowerCase().compareTo((a.clientName ?? '').toLowerCase()));
        break;
      case 'date_asc':
        filteredOrders.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case 'date_desc':
      default:
        filteredOrders.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
    }
  }

  // Small reusable UI helpers used by the dialog form below.
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    TextEditingController? controller,
    String? label,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    Widget? suffixIcon,
    Color? fillColor,
    Color? textColor,
  }) {
    return TextFormField(
      style: TextStyle(color: textColor ?? Colors.blueGrey[900]),
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: onTap != null,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor ?? Colors.blueGrey[900]),
        prefixIcon:
            icon != null ? Icon(icon, color: Colors.blue.shade600) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor ?? Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildProductAdditionRow(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Product input on its own row
        _buildModernTextField(
          controller: _productController,
          label: 'Product Name',
          icon: Icons.inventory_2,
        ),
        const SizedBox(height: 8),
        // Quantity on the next line with the add/save button
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _quantityController,
                label: 'Qty',
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
                fillColor: Colors.blue.shade50,
                textColor: Colors.blueGrey[900],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final prod = _productController.text.trim();
                final qtyText = _quantityController.text.trim();
                if (prod.isEmpty || qtyText.isEmpty) return;
                final qty = int.tryParse(qtyText) ?? 0;
                setDialogState(() {
                  if (_editingProductIndex != null &&
                      _editingProductIndex! >= 0 &&
                      _editingProductIndex! < _currentProducts.length) {
                    // Save edited product
                    _currentProducts[_editingProductIndex!] = {
                      'name': prod,
                      'quantity': qty,
                    };
                    _editingProductIndex = null;
                  } else {
                    // Add new product
                    _currentProducts.add({'name': prod, 'quantity': qty});
                  }
                  _productController.clear();
                  _quantityController.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Icon(
                _editingProductIndex != null ? Icons.save : Icons.add,
                color: Colors.white,
              ),
            ),
          ],
        ),
        if (_currentProducts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Column(
            children:
                _currentProducts
                    .asMap()
                    .entries
                    .map(
                      (e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e.value['name']}'),
                        subtitle: Text('Qty: ${e.value['quantity']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: Colors.blue.shade600,
                              ),
                              onPressed:
                                  () => setDialogState(() {
                                    // populate inputs and switch to edit mode
                                    _productController.text =
                                        e.value['name'] ?? '';
                                    _quantityController.text =
                                        (e.value['quantity'] ?? 0).toString();
                                    _editingProductIndex = e.key;
                                  }),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red.shade400,
                              ),
                              onPressed:
                                  () => setDialogState(() {
                                    // if deleting the item being edited, clear editors
                                    if (_editingProductIndex != null &&
                                        _editingProductIndex == e.key) {
                                      _editingProductIndex = null;
                                      _productController.clear();
                                      _quantityController.clear();
                                    }
                                    _currentProducts.removeAt(e.key);
                                  }),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blueGrey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? Colors.blueGrey[900],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      // order statuses
      case 'confirmed':
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'dispatched':
      case 'shipped':
      case 'in_transit':
        return Colors.blue;
      case 'pending_approval':
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      // payment statuses
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

// Painter for the small top-right status triangle on order cards.
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final path = Path();
    // triangle pointing from top-right corner inward
    path.moveTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, paint);

    // subtle white border for contrast
    final border =
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
