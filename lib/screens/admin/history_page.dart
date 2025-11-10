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
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<OrderHistory> _historyOrders = [];
  bool _isLoading = true;
  final ShipmentService _shipmentService = ShipmentService();
  final TextEditingController _searchController = TextEditingController();
  List<OrderHistory> _displayOrders = [];

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
    });
  }

  void _showOrderDetails(OrderHistory order) {
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
              String _computeFinalFromDispatch() {
                if (order.dispatchDate == null || order.dispatchDate!.isEmpty)
                  return 'N/A';
                final base = DateTime.tryParse(order.dispatchDate!);
                if (base == null) return 'N/A';
                final after = order.afterDispatchDays;
                if (after <= 0) return 'N/A';
                final finalDt = base.add(Duration(days: after));
                return _formatDateString(finalDt.toIso8601String());
              }

              final finalDateText = _computeFinalFromDispatch();

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
                              // Show primary identifiers on separate lines to avoid overflow
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
                                      ConnectionState.waiting)
                                    return const Text('Loading products...');
                                  final items = snap.data ?? [];
                                  if (items.isEmpty)
                                    return _buildDetailRow('Products', 'None');

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
                                  final idx = entry.key; // 0-based
                                  final payment = entry.value;
                                  // For user-facing numbering, idx 0 == installment 1 (odd)
                                  final bool isOdd = idx % 2 == 0;
                                  final Color bgColor =
                                      isOdd
                                          ? const Color(
                                            0xFFF0FBF4,
                                          ) // pale green
                                          : const Color(
                                            0xFFF4FAFF,
                                          ); // pale blue
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
        title: const Text(
          'Order History',
          style: TextStyle(color: Color.fromARGB(255, 204, 201, 201)),
        ),
        leading: BackToDashboardButton(),
        centerTitle: false,
        elevation: 4,
        // glossy gradient header
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade900, Colors.grey.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // subtle glossy highlight
              Positioned(
                top: 6,
                left: 12,
                right: -40,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
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
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.clear,
                                        size: 18,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
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

    String initials() {
      final name = order.clientName ?? order.orderNumber ?? '';
      final parts = name.split(' ').where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) return '#';
      if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    return WireCard(
      title: order.orderNumber ?? 'Order #${order.id}',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.blue.shade50,
              child: Text(
                initials(),
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                order.clientName ?? '-',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? 'Payment Pending' : 'Paid',
                    style: TextStyle(
                      color: statusColor.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  tooltip: 'View Details',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.remove_red_eye_outlined,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: () => _showOrderDetails(order),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // _buildInfoChip removed — history cards now show minimal info; details are in dialog
}
