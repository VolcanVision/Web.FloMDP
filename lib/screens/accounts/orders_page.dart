import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/orders_service.dart';
import '../../services/order_payments_service.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/order_installment.dart';
import 'package:intl/intl.dart';

import '../../models/shipment.dart';
import '../../services/shipment_service.dart';
import '../../theme/pastel_colors.dart';
import '../../services/advance_payments_service.dart';
import '../../widgets/back_to_dashboard.dart';

class AccountsOrdersPage extends StatefulWidget {
  final int? filterId;
  const AccountsOrdersPage({super.key, this.filterId});

  @override
  State<AccountsOrdersPage> createState() => _AccountsOrdersPageState();
}

class _AccountsOrdersPageState extends State<AccountsOrdersPage> {
  List<Order> _orders = [];
  List<Order> filteredOrders = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  final Map<int, List<OrderItem>> _orderItemsCache = {};
  final Map<int, double> _advanceCache = {};
  final Map<int, Shipment> _shipmentMap = {};
  
  // Sort options
  String _sortBy = 'date_desc'; // 'name_asc', 'name_desc', 'date_asc', 'date_desc'

  // Form controllers for creating order
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
  final List<Map<String, dynamic>> _currentProducts = [];
  int? _editingProductIndex;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final allOrders = await OrdersService.instance.getOrders();
      // Sort by date (newest first)
      allOrders.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(0);
        final dateB = b.createdAt ?? DateTime(0);
        return dateB.compareTo(dateA);
      });

      final List<Order> displayedOrders;
      if (widget.filterId != null) {
        displayedOrders =
            allOrders.where((o) => o.id == widget.filterId).toList();
      } else {
        displayedOrders = allOrders;
      }
      
      _orderItemsCache.clear();
      _advanceCache.clear();
      _shipmentMap.clear();

      // Load shipments
      try {
        final allShipments = await ShipmentService().getAllShipments();
        for (final s in allShipments) {
           if (!_shipmentMap.containsKey(s.orderId)) {
            _shipmentMap[s.orderId] = s;
          }
        }
      } catch (e) {
        debugPrint('Error loading shipments: $e');
      }

      for (final order in displayedOrders) {
        if (order.id != null) {
          final items =
              await OrdersService.instance.getOrderItemsForOrder(
                order.id!,
              );
          _orderItemsCache[order.id!] = items;
          
          _advanceCache[order.id!] = await AdvancePaymentsService.instance
              .getTotalAdvancePaid(order.id!);
        }
      }
      setState(() {
        _orders = displayedOrders;
        filteredOrders = displayedOrders;
        _isLoading = false;
      });
      _onSearchChanged();

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
    if (status == null) return Colors.green;
    switch (status.toLowerCase()) {
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

  void _showOrderDialog(Order order, List<OrderItem> items) {
    showDialog(
      context: context,
      builder: (ctx) => _OrderDetailDialog(
        order: order,
        items: items,
        onInstallmentAdded: () {
          _loadOrders();
        },
      ),
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredOrders = List.from(_orders);
        _sortOrders();
      });
      return;
    }
    setState(() {
      filteredOrders =
          _orders.where((order) {
            final clientName = order.clientName?.toLowerCase() ?? '';
             final orderNum = order.orderNumber?.toLowerCase() ?? '';
            return clientName.contains(query) || orderNum.contains(query);
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
                          _buildSectionHeader('Create New Order'),
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
            child: const Text('Cancel'),
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
            ),
            child: const Text('Create Order'),
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
      final advancePaid = _advanceController.text.isEmpty
          ? 0.0
          : double.parse(_advanceController.text);

      String dueDateStr = _dueController.text.trim();
      DateTime dueDate;
      try {
        dueDate = DateTime.parse(dueDateStr);
      } catch (_) {
        dueDate = DateTime.now();
        dueDateStr = dueDate.toIso8601String();
      }

      String? finalDue;
      if (_finalDueDateController.text.trim().isNotEmpty) {
        finalDue = _finalDueDateController.text.trim();
      } else if (_afterDispatchController.text.trim().isNotEmpty &&
          int.tryParse(_afterDispatchController.text) != null) {
        finalDue = dueDate
            .add(Duration(days: int.parse(_afterDispatchController.text)))
            .toIso8601String();
      }

      double totalAmount = 0.0;
      if (_totalController.text.isNotEmpty &&
          double.tryParse(_totalController.text) != null) {
        totalAmount = double.parse(_totalController.text);
      }

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
        orderStatus: 'pending_approval', 
      );

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
        const SnackBar(content: Text('Order created (Pending Approval)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey[800],
      ),
    );
  }

  Widget _buildModernTextField({
    TextEditingController? controller,
    String? label,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
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
        _buildModernTextField(
          controller: _productController,
          label: 'Product Name',
          icon: Icons.inventory_2,
        ),
        const SizedBox(height: 8),
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
                   _currentProducts.add({'name': prod, 'quantity': qty});
                  _productController.clear();
                  _quantityController.clear();
                });
              },
               child: const Icon(Icons.add, color: Colors.white),
               style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.all(14),
               ),
            ),
          ],
        ),
        if (_currentProducts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Column(
             children: _currentProducts.map((p) => ListTile(
                title: Text(p['name']),
                trailing: Text('x${p['quantity']}'),
                dense: true,
             )).toList(),
          ),
        ]
      ],
    );
  }

  Widget _buildOrderTile(Order o) {
    // Uses cached items/payments if available
    final items = _orderItemsCache[o.id] ?? [];
    double totalAdvance = _advanceCache[o.id] ?? o.advancePaid;
    
    // Fallback if not in cache (should be, but safe bet)
    final pendingAmount = o.totalAmount - totalAdvance;
    final isPaid = pendingAmount <= 0.0;
    final isPartial = !isPaid && totalAdvance > 0.0;
    
    // Status Logic matches Admin
    final shipment = _shipmentMap[o.id];
    final displayStatus = shipment?.status ?? o.orderStatus;
    final displayLocation = (shipment != null && shipment.location != null && shipment.location!.isNotEmpty)
            ? shipment.location
            : o.location;

    final statusColor = _getStatusColor(displayStatus);

    return InkWell(
      onTap: () => _showOrderDialog(o, items),
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
                    const SizedBox(width: 8),
                     // Payment Status pill
                    _buildMiniTag(
                      (pendingAmount <= 1.0 ? 'PAID' : (totalAdvance > 0 ? 'PARTIAL' : 'UNPAID')),
                      (pendingAmount <= 1.0 ? Colors.green : (totalAdvance > 0 ? Colors.orange : Colors.red)).withOpacity(0.1),
                      (pendingAmount <= 1.0 ? Colors.green : (totalAdvance > 0 ? Colors.orange : Colors.red)),
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
          children: [
            const Text(
              'Orders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage client orders',
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by client or order #',
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
                Expanded(
                  child: filteredOrders.isEmpty
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderTile(filteredOrders[index]);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOrderDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Order',
      ),
    );
  }
}

// Order Detail Dialog with View Order and Add Installments
class _OrderDetailDialog extends StatefulWidget {
  final Order order;
  final List<OrderItem> items;
  final VoidCallback onInstallmentAdded;

  const _OrderDetailDialog({
    required this.order,
    required this.items,
    required this.onInstallmentAdded,
  });

  @override
  State<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<_OrderDetailDialog> {
  final _paymentsService = OrderPaymentsService();
  List<OrderInstallment> _installments = [];
  bool _isLoading = true;
  
  final _amountController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadInstallments();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadInstallments() async {
    setState(() => _isLoading = true);
    try {
      final installments = await _paymentsService.getInstallments(widget.order.id!);
      setState(() {
        _installments = installments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addInstallment() async {
    if (_amountController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount and select date')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    try {
      final newInstallment = OrderInstallment(
        orderId: widget.order.id!,
        installmentNumber: _installments.length + 1,
        amount: amount,
        dueDate: _selectedDate!.toIso8601String().split('T')[0],
        isPaid: false,
      );
      
      await _paymentsService.addInstallment(newInstallment);
      _amountController.clear();
      setState(() => _selectedDate = null);
      await _loadInstallments();
      widget.onInstallmentAdded();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installment added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding installment: $e')),
      );
    }
  }

  double get _totalPaid {
    return _installments.where((i) => i.isPaid).fold(0.0, (sum, i) => sum + i.amount);
  }

  double get _pendingAmount {
    return widget.order.totalAmount - widget.order.advancePaid - _totalPaid;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final items = widget.items;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: const Icon(Icons.shopping_cart, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'View Order',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client info
                    Text(
                      'Client: ${order.clientName ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Order details fields
                    _buildDetailField(
                      icon: Icons.attach_money,
                      label: 'Total Amount',
                      value: order.totalAmount.toStringAsFixed(1),
                    ),
                    _buildDetailField(
                      icon: Icons.calendar_today,
                      label: 'Expected Dispatch Date',
                      value: order.dueDate,
                      hasCalendarButton: true,
                    ),
                    _buildDetailField(
                      icon: Icons.local_shipping,
                      label: 'Dispatch Date',
                      value: order.dispatchDate ?? 'Not dispatched',
                      hasCalendarButton: true,
                    ),
                    _buildDetailField(
                      icon: Icons.access_time,
                      label: 'After Dispatch Days',
                      value: '${order.afterDispatchDays}',
                    ),
                    _buildDetailField(
                      icon: Icons.date_range,
                      label: 'Final Payment Date',
                      value: order.finalDueDate ?? 'N/A',
                      hasCalendarButton: true,
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Products',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName}  —  Qty: ${item.quantity}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
                        ],
                      ),
                    )),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Payments section
                    const Text(
                      'Payments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentRow('Total', '₹${order.totalAmount.toStringAsFixed(2)}'),
                    _buildPaymentRow('Advance Paid', '₹${order.advancePaid.toStringAsFixed(2)}'),
                    _buildPaymentRow(
                      'Pending',
                      '₹${_pendingAmount.toStringAsFixed(2)}',
                      valueColor: Colors.red,
                    ),
                    _buildPaymentRow(
                      'Payment Status',
                      order.paymentStatus.toUpperCase(),
                      isStatus: true,
                      statusColor: order.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Installments section
                    const Text(
                      'Installments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created: ${order.createdAt != null ? DateFormat('MMM dd, yyyy').format(order.createdAt!) : 'N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Updated: ${order.updatedAt != null ? DateFormat('MMM dd, yyyy').format(order.updatedAt!) : 'N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (order.dueDate.isNotEmpty)
                      Text(
                        'Expected Dispatch Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(order.dueDate))}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    if (order.finalDueDate != null)
                      Text(
                        'Final Payment Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(order.finalDueDate!))}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    if (order.dispatchDate != null)
                      Text(
                        'Dispatch Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(order.dispatchDate!))}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Add installment form
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount field
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.currency_rupee, color: Colors.blue.shade700),
                              hintText: 'Amount',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Date picker
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                setState(() => _selectedDate = date);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.blue.shade700),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedDate == null
                                        ? 'Select Date'
                                        : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                                    style: TextStyle(
                                      color: _selectedDate == null
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Add button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _addInstallment,
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Existing installments list
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ..._installments.map((inst) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: inst.isPaid ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: inst.isPaid ? Colors.green.shade200 : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              inst.isPaid ? Icons.check_circle : Icons.radio_button_off,
                              color: inst.isPaid ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₹${inst.amount.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'Date: ${inst.dueDate}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!inst.isPaid)
                              TextButton(
                                onPressed: () async {
                                  await _paymentsService.markInstallmentPaid(inst.id!, true);
                                  await _loadInstallments();
                                  widget.onInstallmentAdded();
                                },
                                child: const Text('Mark Paid'),
                              ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onInstallmentAdded();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildDetailField({
    required IconData icon,
    required String label,
    required String value,
    bool hasCalendarButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          suffixIcon: hasCalendarButton
              ? Icon(Icons.calendar_today, color: Colors.grey.shade400)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        child: Text(value),
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {
    Color? valueColor,
    bool isStatus = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (statusColor ?? Colors.orange).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: (statusColor ?? Colors.orange).withOpacity(0.3)),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: statusColor ?? Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
        ],
      ),
    );
  }
}

// Painter for the small top-right status triangle on order cards.
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
