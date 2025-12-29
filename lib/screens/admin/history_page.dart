import '../../auth/auth_service.dart';
import '../../models/order_item.dart';
import '../../services/orders_service.dart';
import 'package:flutter/material.dart';
import '../../models/order_history.dart';
import '../../models/advance_payment.dart';
import '../../services/shipment_service.dart';
import '../../services/advance_payments_service.dart';
import '../../widgets/back_to_dashboard.dart';
import '../../widgets/wire_card.dart';

class HistoryPage extends StatefulWidget {
  final UserRole? role;
  const HistoryPage({super.key, this.role});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<OrderHistory> _historyOrders = [];
  bool _isLoading = true;
  final ShipmentService _shipmentService = ShipmentService();
  final TextEditingController _searchController = TextEditingController();
  List<OrderHistory> _displayOrders = [];
  
  // Sort options
  String _sortBy = 'date_desc'; // 'name_asc', 'name_desc', 'date_asc', 'date_desc'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _shipmentService.getOrderHistory();
      setState(() {
        _historyOrders = history.take(30).toList();
        _displayOrders = List.from(_historyOrders);
        _sortOrders();
        _isLoading = false;
      });

      if (_historyOrders.isEmpty && _shipmentService.lastError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Database issue: ${_shipmentService.lastError}\n\nPlease run the SQL script from RUN_THIS_SQL_NOW.md',
              ),
              duration: const Duration(seconds: 10),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading history: $e\n\nMake sure you ran the SQL script!',
            ),
            duration: const Duration(seconds: 8),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateString(String? iso) {
    if (iso == null) return 'N/A';
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  void _sortOrders() {
    switch (_sortBy) {
      case 'name_asc':
        _displayOrders.sort((a, b) => (a.clientName ?? '').toLowerCase().compareTo((b.clientName ?? '').toLowerCase()));
        break;
      case 'name_desc':
        _displayOrders.sort((a, b) => (b.clientName ?? '').toLowerCase().compareTo((a.clientName ?? '').toLowerCase()));
        break;
      case 'date_asc':
        _displayOrders.sort((a, b) {
          final aDate = DateTime.tryParse(a.shippedAt ?? '') ?? DateTime(1970);
          final bDate = DateTime.tryParse(b.shippedAt ?? '') ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case 'date_desc':
      default:
        _displayOrders.sort((a, b) {
          final aDate = DateTime.tryParse(a.shippedAt ?? '') ?? DateTime(1970);
          final bDate = DateTime.tryParse(b.shippedAt ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
    }
  }

  void _onSearchChanged(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayOrders = List.from(_historyOrders);
      } else {
        _displayOrders =
            _historyOrders.where((o) {
              final client = (o.clientName ?? '').toLowerCase();
              final orderNo = (o.orderNumber ?? '').toLowerCase();
              return client.contains(query) || orderNo.contains(query);
            }).toList();
      }
      _sortOrders();
    });
  }

  void _showOrderDetails(OrderHistory order) {
    // For production role, show a simplified dialog
    if (widget.role == UserRole.production) {
      _showProductionOrderDetails(order);
      return;
    }
    
    // Full dialog for admin/accounts
    showDialog(
      context: context,
      builder:
          (context) => FutureBuilder<List<AdvancePayment>>(
            future:
                order.id != null
                    ? AdvancePaymentsService.instance.getPaymentsForOrder(
                      order.id!,
                    )
                    : Future.value([]),
            builder: (context, snapshot) {
              final advances = snapshot.data ?? [];
              final totalAdvancePaid = advances.fold<double>(
                0.0,
                (sum, p) => sum + p.amount,
              );

              // compute final installment date locally as dispatchDate + afterDispatchDays
              String computeFinalFromDispatch() {
                if (order.dispatchDate == null || order.dispatchDate!.isEmpty) {
                  return 'N/A';
                }
                final base = DateTime.tryParse(order.dispatchDate!);
                if (base == null) return 'N/A';
                final after = order.afterDispatchDays;
                if (after <= 0) return 'N/A';
                final finalDt = base.add(Duration(days: after));
                return _formatDateString(finalDt.toIso8601String());
              }

              final finalDateText = computeFinalFromDispatch();

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 760,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade800,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Order Details',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                'Order No.',
                                order.orderNumber ?? 'N/A',
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Client',
                                order.clientName ?? 'N/A',
                              ),
                              const SizedBox(height: 8),
                              FutureBuilder<List<OrderItem>>(
                                future:
                                    order.id != null
                                        ? OrdersService.instance
                                            .getOrderItemsForOrder(order.id!)
                                        : Future.value([]),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text('Loading products...');
                                  }
                                  final items = snap.data ?? [];
                                  if (items.isEmpty) {
                                    return _buildDetailRow('Products', 'None');
                                  }

                                  final lines = items
                                      .map(
                                        (i) =>
                                            '${i.productName} (Qty: ${i.quantity})',
                                      )
                                      .join('\n');
                                  return _buildDetailRow('Products', lines);
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Due Date',
                                _formatDateString(order.dueDate),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Dispatch Date',
                                _formatDateString(order.dispatchDate),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Total Amount',
                                '\u20b9${order.totalAmount.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 16, thickness: 1),
                              
                              // Shipment Details Section
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Shipment Details:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                              _buildDetailRow(
                                'Shipping Company',
                                order.shippingCompany ?? '-',
                              ),
                              const SizedBox(height: 4),
                              _buildDetailRow(
                                'Vehicle',
                                order.vehicleDetails ?? '-',
                              ),
                              const SizedBox(height: 4),
                              _buildDetailRow(
                                'Driver Contact',
                                order.driverContact ?? '-',
                              ),
                              const SizedBox(height: 4),
                              _buildDetailRow(
                                'Incharge',
                                order.shipmentIncharge ?? '-',
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 16, thickness: 1),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Installments:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (advances.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'No installments recorded',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              else
                                ...advances.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final payment = entry.value;
                                  final bool isOdd = idx % 2 == 0;
                                  final Color bgColor =
                                      isOdd
                                          ? const Color(0xFFF0FBF4)
                                          : const Color(0xFFF4FAFF);
                                  final Color titleColor =
                                      isOdd
                                          ? Colors.green.shade800
                                          : Colors.blue.shade800;

                                  return Card(
                                    color: bgColor,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(
                                        '\$${payment.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: titleColor,
                                        ),
                                      ),
                                      subtitle:
                                          payment.note != null &&
                                                  payment.note!.isNotEmpty
                                              ? Text(
                                                payment.note!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              )
                                              : null,
                                      trailing: Text(
                                        _formatDateString(payment.paidAt),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              if (advances.isNotEmpty)
                                _buildDetailRow(
                                  'Total Installments',
                                  '\$${totalAdvancePaid.toStringAsFixed(2)}',
                                  color: Colors.green[700],
                                  isBold: true,
                                ),
                              const Divider(height: 16, thickness: 1),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailRow(
                                      'Final Installment Date',
                                      _formatDateString(finalDateText),
                                      color:
                                          advances.isNotEmpty
                                              ? Colors.green[700]
                                              : null,
                                    ),
                                  ),
                                ],
                              ),
                              _buildDetailRow(
                                'Days After Dispatch',
                                '${order.afterDispatchDays}',
                              ),
                              const Divider(height: 24, thickness: 2),
                              _buildDetailRow(
                                'Batch No.',
                                order.batchNo ?? 'N/A',
                                isBold: true,
                              ),
                              _buildDetailRow(
                                'Batch Details',
                                order.batchDetails ?? 'N/A',
                              ),
                              const Divider(height: 24, thickness: 2),
                              _buildDetailRow(
                                'Pending Amount',
                                '\$${order.pendingAmount.toStringAsFixed(2)}',
                                color:
                                    order.pendingAmount > 0
                                        ? Colors.red[700]
                                        : Colors.green[700],
                                isBold: true,
                              ),
                              _buildDetailRow(
                                'Shipped At',
                                _formatDateString(order.shippedAt),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
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

  /// Simplified dialog for production role - shows only essential info
  void _showProductionOrderDetails(OrderHistory order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Order Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
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
                      _buildCompactRow('Client', order.clientName ?? 'N/A'),
                      _buildCompactRow('Order No.', order.orderNumber ?? 'N/A'),
                      FutureBuilder<List<OrderItem>>(
                        future: order.id != null
                            ? OrdersService.instance.getOrderItemsForOrder(order.id!)
                            : Future.value([]),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return _buildCompactRow('Products', 'Loading...');
                          }
                          final items = snap.data ?? [];
                          if (items.isEmpty) {
                            return _buildCompactRow('Products', 'None');
                          }
                          final lines = items.map((i) => '${i.productName} x${i.quantity}').join(', ');
                          return _buildCompactRow('Products', lines);
                        },
                      ),
                      const Divider(height: 16),
                      _buildCompactRow('Due Date', _formatDateString(order.dueDate)),
                      _buildCompactRow('Dispatch Date', _formatDateString(order.dispatchDate)),
                      _buildCompactRow('Days After Dispatch', '${order.afterDispatchDays}'),
                      const Divider(height: 16),
                      _buildCompactRow('Batch No.', order.batchNo ?? 'N/A'),
                      _buildCompactRow('Batch Details', order.batchDetails ?? 'N/A'),
                      const Divider(height: 16),
                      _buildCompactRow('Shipped At', _formatDateString(order.shippedAt)),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildCompactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    int? maxLines,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              softWrap: true,
              maxLines: maxLines,
              overflow:
                  maxLines != null
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Completed Transactions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        leading: const BackToDashboardButton(),
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 76,
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
            colors: [const Color(0xFFF8FAFC), const Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyOrders.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No shipped orders yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade700,
                                      Colors.blue.shade400,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.shade700.withOpacity(
                                        0.18,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by client or order number',
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintStyle: TextStyle(
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.clear,
                                        size: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                              // Sort dropdown
                              PopupMenuButton<String>(
                                icon: Icon(Icons.sort, size: 20, color: Colors.grey[600]),
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadHistory,
                        child:
                            _displayOrders.isEmpty
                                ? ListView(
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    Center(
                                      child: Text(
                                        _searchController.text.isEmpty
                                            ? 'No shipped orders yet'
                                            : 'No matches for "${_searchController.text}"',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _displayOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = _displayOrders[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildHistoryCard(order),
                                    );
                                  },
                                ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildHistoryCard(OrderHistory order) {
    final isPending = order.pendingAmount > 0;
    final statusColor = isPending ? Colors.orange : Colors.green;
    final isProduction = widget.role == UserRole.production;
    final themeColor = isProduction ? Colors.purple : Colors.blue;

    String initials() {
      final name = order.clientName ?? order.orderNumber ?? '';
      final parts = name.split(' ').where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) return '#';
      if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    return WireCard(
      title: order.orderNumber ?? 'Order #${order.id}',
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: themeColor.shade50,
                child: Text(
                  initials(),
                  style: TextStyle(
                    color: themeColor.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      order.clientName ?? '-',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Shipped: ${_formatDateString(order.shippedAt)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Show payment status for non-production, batch info for production
              if (!isProduction)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isPending ? 'Pending' : 'Paid',
                    style: TextStyle(
                      color: statusColor.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                  ),
                )
              else if (order.batchNo != null)
                Text(
                  order.batchNo!,
                  style: TextStyle(fontSize: 10, color: Colors.purple[400], fontWeight: FontWeight.w500),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // _buildInfoChip removed — history cards now show minimal info; details are in dialog
}
