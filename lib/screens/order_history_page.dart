import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_history.dart';
import '../services/excel_export_service.dart';
import '../services/shipment_service.dart';
import '../widgets/back_to_dashboard.dart';
import '../widgets/wire_card.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<OrderHistory> _history = [];
  bool _isLoading = true;
  final ShipmentService _shipmentService = ShipmentService();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _shipmentService.getOrderHistory();
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    }
  }

  /// Export all order history to Excel/CSV
  Future<void> _exportHistoryToExcel() async {
    try {
      final headers = [
        'Order No.',
        'Client Name',
        'Products & Quantity',
        'Expected Dispatch Date',
        'Total Amount',
        'Total Installments',
        'Pending Amount',
        'Batch No.',
        'Batch Details',
        'Shipment Details',
        'Vehicle Number',
        'Date of Delivery',
      ];

      final List<List<dynamic>> rows = _history.map((order) {
        return [
          order.orderNumber ?? '',
          order.clientName ?? '',
          order.productsList ?? '',
          order.dueDate ?? '',
          order.totalAmount.toStringAsFixed(2),
          order.advancePaid.toStringAsFixed(2),
          order.pendingAmount.toStringAsFixed(2),
          order.batchNo ?? '',
          order.batchDetails ?? '',
          '', // Shipment Details
          '', // Vehicle Number
          order.shippedAt ?? '',
        ];
      }).toList();

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: 'order_history_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order history exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOrderDetails(OrderHistory order) {
    // Parse installments from advancePaymentDate if possible (comma separated or list)
    List<Map<String, dynamic>> installments = [];
    if (order.advancePaid > 0) {
      // If advancePaymentDate is a comma separated list, parse it
      if (order.advancePaymentDate != null &&
          order.advancePaymentDate!.contains(',')) {
        final dates = order.advancePaymentDate!.split(',');
        final amounts = order.advancePaid.toString().split(',');
        for (int i = 0; i < dates.length; i++) {
          installments.add({
            'amount':
                (i < amounts.length)
                    ? amounts[i]
                    : order.advancePaid.toString(),
            'date': dates[i],
          });
        }
      } else {
        installments.add({
          'amount': order.advancePaid.toString(),
          'date': order.advancePaymentDate ?? '',
        });
      }
    }
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              constraints: BoxConstraints(maxWidth: 420),
              padding: EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.orderNumber ?? 'Order Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue[900],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.blue[700]),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Order Number',
                            order.orderNumber ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Client Name',
                            order.clientName ?? 'N/A',
                          ),
                          SizedBox(height: 16),
                          _buildSectionTitle('Products'),
                          Card(
                            color: Colors.grey[50],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                order.productsList ?? 'N/A',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildSectionTitle('Dates'),
                          _buildDetailRow('Due Date', order.dueDate ?? 'N/A'),
                          _buildDetailRow(
                            'Dispatch Date',
                            order.dispatchDate ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Shipped At',
                            order.shippedAt ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Days After Dispatch',
                            order.afterDispatchDays.toString(),
                          ),
                          SizedBox(height: 16),
                          _buildSectionTitle('Payment'),
                          Card(
                            color: Colors.blue[50],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    'Total Amount',
                                    '\u20b9${order.totalAmount.toStringAsFixed(2)}',
                                  ),
                                  ...installments.map(
                                    (inst) => Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.payments,
                                            color: Colors.indigo,
                                            size: 18,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Installment: ₹${inst['amount']} on ${inst['date']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  _buildDetailRow(
                                    'Pending Amount',
                                    '4${order.pendingAmount.toStringAsFixed(2)}',
                                    isHighlight: order.pendingAmount > 0,
                                  ),
                                  _buildDetailRow(
                                    'Final Payment Date',
                                    order.finalPaymentDate ?? 'N/A',
                                  ),
                                  _buildDetailRow(
                                    'Payment Due Date',
                                    order.paymentDueDate ?? 'N/A',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildSectionTitle('Production'),
                          Card(
                            color: Colors.grey[50],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    'Batch Number',
                                    order.batchNo ?? 'N/A',
                                  ),
                                  _buildDetailRow(
                                    'Batch Details',
                                    order.batchDetails ?? 'N/A',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 16, bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? Colors.red : Colors.black87,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
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
              'Order History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'View past completed orders',
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
            tooltip: 'Download History (Excel)',
            onPressed: _exportHistoryToExcel,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _history.isEmpty
              ? Center(
                child: Text(
                  'No shipped orders yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final order = _history[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: WireCard(
                      title: order.orderNumber ?? 'Order #${order.id}',
                      child: InkWell(
                        onTap: () => _showOrderDetails(order),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.clientName ?? 'N/A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(order.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          (order.status ?? 'SHIPPED').toUpperCase().replaceAll('_', ' '),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(order.status),
                                          ),
                                        ),
                                      ),
                                      if (order.destination != null && order.destination!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                                              SizedBox(width: 2),
                                              Container(
                                                constraints: BoxConstraints(maxWidth: 100),
                                                child: Text(
                                                  order.destination!,
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.right,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text('Shipped: ${order.shippedAt ?? 'N/A'}'),
                              Text('Batch: ${order.batchNo ?? 'N/A'}'),
                              Text(
                                'Pending: \$${order.pendingAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color:
                                      order.pendingAmount > 0
                                          ? Colors.red
                                          : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Tap for details',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.green[800]!;
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.blue[800]!;
      case 'shipped':
      case 'in_transit':
        return Colors.orange[800]!;
      default:
        return Colors.green[800]!;
    }
  }
}
