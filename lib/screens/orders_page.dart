import 'package:flutter/material.dart';
import '../models/advance_payment.dart';
import '../services/advance_payments_service.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/orders_service.dart';

/// Clean, minimal Orders page that shows the orders list by default and
/// provides a glossy FloatingActionButton to add new orders via a dialog.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Map<int, double> _advanceCache = {};
  // status filter removed per user request
  List<Order> orders = [];
  List<Order> filteredOrders = [];
  final TextEditingController _searchController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  final _totalController = TextEditingController();
  final _advanceController = TextEditingController();
  final _dueController = TextEditingController();
  final _afterDispatchController = TextEditingController();
  final _finalDueDateController = TextEditingController();
  bool _isAdvancePaid = false;

  // Product list for the current order
  List<Map<String, dynamic>> _currentProducts = [];
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
      _advanceCache.clear();
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

  Future<void> _showAddOrderDialog() async {
    // Restore the full create-order dialog using the existing form helpers.
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Create Order',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
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

                        const SizedBox(height: 8),

                        _buildModernTextField(
                          controller: _clientNameController,
                          label: 'Client Name',
                          icon: Icons.person,
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                        ),

                        const SizedBox(height: 12),

                        _buildSectionHeader('Products'),
                        const SizedBox(height: 8),
                        _buildProductAdditionRow((fn) => setState(fn)),

                        const SizedBox(height: 12),

                        _buildSectionHeader('Dates'),
                        const SizedBox(height: 8),
                        _buildDateFields((fn) => setState(fn)),

                        const SizedBox(height: 12),

                        _buildSectionHeader('Payment'),
                        const SizedBox(height: 8),
                        _buildAdvancePaymentSection((fn) => setState(fn)),

                        const SizedBox(height: 16),

                        _buildActionButtons(ctx),
                      ],
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
          // Total Amount field above installments
          _buildModernTextField(
            controller: _totalController,
            label: 'Total Amount',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
            validator:
                (v) =>
                    (v != null && v.isNotEmpty && double.tryParse(v) == null)
                        ? 'Invalid'
                        : null,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _isAdvancePaid,
            onChanged: (v) => setDialogState(() => _isAdvancePaid = v ?? false),
            title: const Text('Installement Received'),
            subtitle: const Text('Check if client has made an Installment'),
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
              validator:
                  (v) =>
                      (v != null && v.isNotEmpty && double.tryParse(v) == null)
                          ? 'Invalid'
                          : null,
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
          label: 'Due Date',
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
          suffixIcon: Icon(Icons.calendar_today, color: Colors.blue.shade600),
        ),
        const SizedBox(height: 12),
        // Stack vertically on mobile for better visibility
        _buildModernTextField(
          controller: _afterDispatchController,
          label: 'After Dispatch Days',
          icon: Icons.schedule,
          keyboardType: TextInputType.number,
          validator:
              (v) =>
                  (v != null && v.isNotEmpty && int.tryParse(v) == null)
                      ? 'Invalid'
                      : null,
        ),
        const SizedBox(height: 12),
        _buildModernTextField(
          controller: _finalDueDateController,
          label: 'Final Due Date (optional)',
          icon: Icons.event,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              _finalDueDateController.text =
                  picked.toIso8601String().split('T')[0];
              setDialogState(() {});
            }
          },
          suffixIcon: Icon(Icons.calendar_today, color: Colors.blue.shade600),
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
        totalAmount: totalAmount,
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
        final productsText =
            items.isEmpty
                ? 'No products'
                : items
                    .map((i) => '${i.productName} (Qty: ${i.quantity})')
                    .join(', ');

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

            return InkWell(
              onTap: () => _showOrderDetailsDialog(o),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade50, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // main content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show client name and order number (if present)
                              Text(
                                // Show client name and prefer an explicit order number
                                // (order.orderNumber). If not present, fall back to the
                                // numeric DB id so every record shows a reference.
                                '${o.clientName ?? 'Client'}' +
                                    (o.orderNumber != null &&
                                            o.orderNumber!.isNotEmpty
                                        ? '  •  #${o.orderNumber}'
                                        : (o.id != null
                                            ? '  •  #${o.id}'
                                            : '')),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.blueGrey[900],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                productsText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey[700],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Boost-style progress bar showing total paid vs total amount
                              Builder(
                                builder: (ctx) {
                                  final paid = totalAdvance;
                                  final total =
                                      o.totalAmount <= 0 ? 0.0 : o.totalAmount;
                                  final fraction =
                                      (total <= 0)
                                          ? 0.0
                                          : (paid / total).clamp(0.0, 1.0);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            FractionallySizedBox(
                                              widthFactor: fraction,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.green.shade600,
                                                      Colors.green.shade400,
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          // small spacer left intentionally empty; numeric labels removed per earlier request
                                          const SizedBox(width: 8),
                                          if (total > 0)
                                            Text(
                                              '${(fraction * 100).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blueGrey[700],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 0),
                      ],
                    ),
                  ),

                  // top-right status triangle
                  Positioned(
                    top: -2,
                    right: -2,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CustomPaint(
                        painter: _TrianglePainter(statusColor),
                      ),
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
                            child: Text(
                              'Edit Order',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.blue[900],
                              ),
                            ),
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

                      // Installments heading (placed above Amount input)
                      const SizedBox(height: 6),
                      Text(
                        'Installments',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ...existing code...
                      TextField(
                        controller: amountCtrl,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(
                            Icons.currency_rupee,
                            color: Colors.blue.shade600,
                          ),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      // ...existing code...
                      const SizedBox(height: 14),
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
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.blue.shade400,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                selectedDate == null
                                    ? 'Select Date'
                                    : selectedDate.toString().split(' ')[0],
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.blueGrey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ...existing code...
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final amt = double.tryParse(amountCtrl.text);
                              if (amt != null && selectedDate != null) {
                                final payment = AdvancePayment(
                                  orderId: order.id!,
                                  amount: amt,
                                  paidAt:
                                      selectedDate!.toIso8601String().split(
                                        'T',
                                      )[0],
                                );
                                await AdvancePaymentsService.instance
                                    .addPayment(payment);
                                // Refresh installments list
                                installments = await AdvancePaymentsService
                                    .instance
                                    .getPaymentsForOrder(order.id!);
                                setState(() {});
                                Navigator.of(ctx3).pop();
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18),
                                SizedBox(width: 7),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      ...installments.map(
                        (inst) => ListTile(
                          leading: Icon(
                            Icons.payments,
                            color: Colors.blue.shade400,
                          ),
                          title: Text(
                            '₹${inst.amount}',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('Date: ${inst.paidAt}'),
                        ),
                      ),
                      // Delete order button at bottom
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: Icon(
                              Icons.delete_forever,
                              color: Colors.red.shade600,
                            ),
                            label: Text(
                              'Delete Order',
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade100),
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx3,
                                builder:
                                    (c) => AlertDialog(
                                      title: Text('Delete Order'),
                                      content: Text(
                                        'Are you sure you want to delete this order? This cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(c).pop(false),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(c).pop(true),
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirmed != true) return;
                              final ok = await OrdersService.instance
                                  .deleteOrder(order.id!);
                              if (ok) {
                                Navigator.of(ctx3).pop();
                                await _loadOrders();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Order deleted')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete order'),
                                  ),
                                );
                              }
                            },
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
      appBar: AppBar(
        title: Text('Orders'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 12),
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
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredOrders = orders;
      });
      return;
    }
    setState(() {
      filteredOrders =
          orders.where((order) {
            final clientName = order.clientName?.toLowerCase() ?? '';
            return clientName.contains(query);
          }).toList();
    });
  }

  // Small reusable UI helpers used by the dialog form below.
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
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
