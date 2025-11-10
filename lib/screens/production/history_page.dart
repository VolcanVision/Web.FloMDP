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

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final history = await _shipmentService.getOrderHistory();
      if (!mounted) return;
      setState(() {
        // Get last 30 shipped orders
        _historyOrders = history.take(30).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
    }
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
                (sum, payment) => sum + payment.amount,
              );

              return AlertDialog(
                title: Text('Order Details'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Order No.', order.orderNumber ?? 'N/A'),
                      _buildDetailRow('Client Name', order.clientName ?? 'N/A'),
                      _buildDetailRow('Products', order.productsList ?? 'N/A'),
                      _buildDetailRow('Due Date', order.dueDate ?? 'N/A'),
                      _buildDetailRow(
                        'Dispatch Date',
                        order.dispatchDate ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Total Amount',
                        '\u20b9${order.totalAmount.toStringAsFixed(2)}',
                      ),
                      Divider(height: 16, thickness: 1),

                      // Installments Section
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Installments:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (advances.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No installments recorded',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ...advances.map(
                          (payment) => Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '\$${payment.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    if (payment.note != null &&
                                        payment.note!.isNotEmpty)
                                      Text(
                                        payment.note!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  payment.paidAt,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (advances.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: _buildDetailRow(
                            'Total Installments',
                            '\$${totalAdvancePaid.toStringAsFixed(2)}',
                            color: Colors.green[700],
                            isBold: true,
                          ),
                        ),

                      Divider(height: 16, thickness: 1),
                      _buildDetailRow(
                        'Final Installment Date',
                        advances.isNotEmpty
                            ? advances
                                .first
                                .paidAt // Last installment date (sorted desc)
                            : (order.finalPaymentDate ?? 'N/A'),
                        color: advances.isNotEmpty ? Colors.green[700] : null,
                      ),
                      _buildDetailRow(
                        'Days After Dispatch',
                        '${order.afterDispatchDays}',
                      ),
                      Divider(height: 24, thickness: 2),
                      _buildDetailRow(
                        'Batch No.',
                        order.batchNo ?? 'N/A',
                        isBold: true,
                      ),
                      _buildDetailRow(
                        'Batch Details',
                        order.batchDetails ?? 'N/A',
                      ),
                      Divider(height: 24, thickness: 2),
                      _buildDetailRow(
                        'Payment Due Date',
                        order.paymentDueDate ?? 'N/A',
                        color: Colors.orange[800],
                      ),
                      _buildDetailRow(
                        'Pending Amount',
                        '\$${order.pendingAmount.toStringAsFixed(2)}',
                        color:
                            order.pendingAmount > 0
                                ? Colors.red[700]
                                : Colors.green[700],
                        isBold: true,
                      ),
                      _buildDetailRow('Shipped At', order.shippedAt ?? 'N/A'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
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
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
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
        title: Text('Order History'),
        leading: BackToDashboardButton(),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _historyOrders.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No shipped orders yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _historyOrders.length,
                  itemBuilder: (context, index) {
                    final order = _historyOrders[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _buildHistoryCard(order),
                    );
                  },
                ),
              ),
    );
  }

  Widget _buildHistoryCard(OrderHistory order) {
    final isPending = order.pendingAmount > 0;

    return WireCard(
      title: order.orderNumber ?? 'Order #${order.id}',
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
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
                      SizedBox(height: 4),
                      Text(
                        order.productsList ?? 'N/A',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPending ? 'Payment Pending' : 'Paid',
                    style: TextStyle(
                      color: isPending ? Colors.orange[900] : Colors.green[900],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.local_shipping,
                    'Shipped: ${order.shippedAt ?? 'N/A'}',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.qr_code,
                    'Batch: ${order.batchNo ?? 'N/A'}',
                    Colors.purple,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    Icons.attach_money,
                    'Pending: \$${order.pendingAmount.toStringAsFixed(2)}',
                    isPending ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(Icons.visibility),
              label: Text('View Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _showOrderDetails(order),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
