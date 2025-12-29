import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/wire_card.dart';
import '../../models/purchase.dart';
import '../../models/purchase_payment.dart';
import '../../services/excel_export_service.dart';
import '../../services/purchases_service.dart';
import '../../services/purchase_payments_service.dart';
import '../../widgets/back_to_dashboard.dart';

class PurchasePage extends StatefulWidget {
  final int? filterId;
  const PurchasePage({super.key, this.filterId});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  List<Purchase> purchases = [];
  bool _isLoading = true;


  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = 'Raw Material';
  final List<String> _categories = [
    'Raw Material',
    'Packaging',
    'Equipment',
    'Office Supplies',
    'Other',
  ];

  Map<int, double> _paidAmounts = {};
  DateTime? _selectedDueDate;

  // Search and Sort state
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'date_desc'; // 'vendor_asc', 'vendor_desc', 'date_asc', 'date_desc'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    _loadPurchases();
  }

  void _sortPurchases() {
    setState(() {
      switch (_sortBy) {
        case 'vendor_asc':
          purchases.sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
          break;
        case 'vendor_desc':
          purchases.sort((a, b) => b.companyName.toLowerCase().compareTo(a.companyName.toLowerCase()));
          break;
        case 'date_asc':
          purchases.sort((a, b) => (a.purchaseDate ?? DateTime(0)).compareTo(b.purchaseDate ?? DateTime(0)));
          break;
        case 'date_desc':
        default:
          purchases.sort((a, b) => (b.purchaseDate ?? DateTime(0)).compareTo(a.purchaseDate ?? DateTime(0)));
          break;
      }
    });
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final allPurchases = await PurchasesService().fetchAll();
      if (widget.filterId != null) {
        purchases = allPurchases.where((p) => p.id == widget.filterId).toList();
      } else {
        purchases = allPurchases;
      }
      
      // Calculate paid amounts for each purchase
      final Map<int, double> amounts = {};
      for (var p in purchases) {
        if (p.id != null) {
          final payments = await PurchasePaymentsService.instance.getPaymentsForPurchase(p.id!);
          amounts[p.id!] = payments.fold(0.0, (sum, pay) => sum + pay.amount);
        }
      }
      _paidAmounts = amounts;
      
      // Initial sort
      _sortPurchases();
      
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading purchases: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Export all purchases to Excel/CSV
  Future<void> _exportAllPurchasesToExcel() async {
    try {
      final headers = [
        'Company/Vendor',
        'Material',
        'Quantity',
        'Unit Cost',
        'Total Amount',
        'Paid Amount',
        'Pending Amount',
        'Purchase Date',
        'Payment Due Date',
        'Payment Status',
        'Notes',
      ];

      final List<List<dynamic>> rows = purchases.map((p) {
        final totalAmount = (p.quantity ?? 0) * (p.cost ?? 0);
        final paidAmount = _paidAmounts[p.id] ?? 0.0;
        final pendingAmount = totalAmount - paidAmount;
        return [
          p.companyName,
          p.material,
          p.quantity?.toString() ?? '',
          p.cost?.toStringAsFixed(2) ?? '',
          totalAmount.toStringAsFixed(2),
          paidAmount.toStringAsFixed(2),
          pendingAmount.toStringAsFixed(2),
          p.purchaseDate != null ? DateFormat('dd/MM/yyyy').format(p.purchaseDate!) : '',
          p.paymentDueDate != null ? DateFormat('dd/MM/yyyy').format(p.paymentDueDate!) : '',
          p.paymentStatus ?? 'unpaid',
          p.notes ?? '',
        ];
      }).toList();

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: 'purchases_export_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Purchases exported successfully!'),
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

  /// Export single purchase with payment details to Excel/CSV
  Future<void> _exportSinglePurchaseToExcel(Purchase p, List<PurchasePayment> installments) async {
    try {
      final totalAmount = (p.quantity ?? 0) * (p.cost ?? 0);
      final totalPaid = installments.fold<double>(0, (sum, i) => sum + i.amount);
      final pendingAmount = totalAmount - totalPaid;

      final headers = ['Field', 'Value'];
      final rows = <List<dynamic>>[
        ['Company/Vendor', p.companyName],
        ['Material', p.material],
        ['Quantity', p.quantity?.toString() ?? ''],
        ['Unit Cost', '₹${p.cost?.toStringAsFixed(2) ?? '0.00'}'],
        ['Total Amount', '₹${totalAmount.toStringAsFixed(2)}'],
        ['Total Paid', '₹${totalPaid.toStringAsFixed(2)}'],
        ['Pending Amount', '₹${pendingAmount.toStringAsFixed(2)}'],
        ['Purchase Date', p.purchaseDate != null ? DateFormat('dd/MM/yyyy').format(p.purchaseDate!) : ''],
        ['Payment Due Date', p.paymentDueDate != null ? DateFormat('dd/MM/yyyy').format(p.paymentDueDate!) : ''],
        ['Payment Status', p.paymentStatus ?? 'unpaid'],
        ['Notes', p.notes ?? ''],
        ['', ''],
        ['PAYMENT HISTORY', ''],
      ];

      // Add payment installments
      for (final payment in installments) {
        final dateStr = payment.paidAt.isNotEmpty
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(payment.paidAt))
            : '';
        rows.add(['  $dateStr', '₹${payment.amount.toStringAsFixed(2)}']);
      }

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: 'purchase_${p.companyName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Purchase exported successfully!'),
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

  Future<void> _deletePurchase(Purchase p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete purchase from ${p.companyName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PurchasesService().remove(p.id!);
      _loadPurchases();
    }
  }

  Future<void> _showPurchaseFormDialog({Purchase? existing}) async {
    final isEdit = existing != null;
    
    if (isEdit) {
      _vendorController.text = existing.companyName;
      _itemController.text = existing.material;
      _quantityController.text = existing.quantity?.toString() ?? '';
      _priceController.text = existing.cost?.toString() ?? '';
      _notesController.text = existing.notes ?? '';
      // _selectedCategory logic if category was in model, currently sticking to default or whatever logic
      _selectedDueDate = existing.paymentDueDate;
    } else {
      _vendorController.clear();
      _itemController.clear();
      _quantityController.clear();
      _priceController.clear();
      _notesController.clear();
      _selectedCategory = 'Raw Material';
      _selectedDueDate = null;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Purchase' : 'Create New Purchase',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSectionHeader('Vendor Information'),
                              const SizedBox(height: 12),
                              _buildModernTextField(
                                controller: _vendorController,
                                label: 'Vendor Name',
                                icon: Icons.business,
                                validator:
                                    (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                              ),
                              const SizedBox(height: 24),

                              _buildSectionHeader('Item Details'),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(
                                    Icons.category,
                                    color: Colors.blue.shade600,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items:
                                    _categories
                                        .map(
                                          (category) => DropdownMenuItem(
                                            value: category,
                                            child: Text(category),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  setDialogState(() => _selectedCategory = value!);
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildModernTextField(
                                controller: _itemController,
                                label: 'Item Name',
                                icon: Icons.inventory_2,
                                validator:
                                    (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildModernTextField(
                                      controller: _quantityController,
                                      label: 'Quantity',
                                      icon: Icons.numbers,
                                      keyboardType: TextInputType.number,
                                      validator:
                                          (v) =>
                                              (v == null || v.isEmpty)
                                                  ? 'Required'
                                                  : (double.tryParse(v) == null
                                                      ? 'Invalid number'
                                                      : null),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildModernTextField(
                                      controller: _priceController,
                                      label: 'Unit Price',
                                      icon: Icons.attach_money,
                                      keyboardType: TextInputType.number,
                                      validator:
                                          (v) =>
                                              (v == null || v.isEmpty)
                                                  ? 'Required'
                                                  : (double.tryParse(v) == null
                                                      ? 'Invalid price'
                                                      : null),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildModernTextField(
                                controller: _notesController,
                                label: 'Notes (Optional)',
                                icon: Icons.note,
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDueDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => _selectedDueDate = picked);
                                  }
                                },
                                child: AbsorbPointer(
                                  child: _buildModernTextField(
                                    controller: TextEditingController(
                                      text: _selectedDueDate != null
                                          ? DateFormat('MMM dd, yyyy').format(_selectedDueDate!)
                                          : '',
                                    ),
                                    label: 'Payment Due Date (Optional)',
                                    icon: Icons.calendar_today,
                                  ),
                                ),
                              ),


                              const SizedBox(height: 24),

                              // Total Amount Display
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Amount:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                    Text(
                                      '₹${(_quantityController.text.isNotEmpty && _priceController.text.isNotEmpty) ? ((double.tryParse(_quantityController.text) ?? 0) * (double.tryParse(_priceController.text) ?? 0)).toStringAsFixed(2) : '0.00'}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        side: BorderSide(
                                          color: Colors.grey.shade400,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await _savePurchase(ctx, existing);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(isEdit ? Icons.save : Icons.add_shopping_cart, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            isEdit ? 'Update Purchase' : 'Create Purchase',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          labelStyle: TextStyle(
            color: Colors.blue.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  Future<void> _savePurchase(BuildContext ctx, Purchase? existing) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      final purchase = Purchase(
        id: existing?.id,
        companyName: _vendorController.text.trim(),
        material: _itemController.text.trim(),
        quantity: double.tryParse(_quantityController.text),
        cost: double.tryParse(_priceController.text),
        notes:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
        purchaseDate: existing?.purchaseDate ?? DateTime.now(),
        // Payment status logic might need better handling, but default to unpaid for new, keep existing for edit or re-calc
        paymentStatus: existing?.paymentStatus ?? 'unpaid',
        paymentDueDate: _selectedDueDate,
      );
      
      Purchase? result;
      if (existing != null) {
        if (await PurchasesService().update(purchase)) {
          // Success update
           result = purchase; // Approximation
           // Actually PurchasesService.update returns bool. 
           // Reloading will fix the object.
        }
      } else {
        result = await PurchasesService().create(purchase);
      }

      if (!mounted) return;
      Navigator.of(ctx).pop();
      // Reload is good enough
      await _loadPurchases();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing != null ? 'Purchase updated!' : 'Purchase created!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showPurchaseDetailsDialog(Purchase p) async {
    List<PurchasePayment> installments = [];
    bool isDialogLoading = true;
    final amountCtrl = TextEditingController();
    DateTime? selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState) {
            if (isDialogLoading) {
              PurchasePaymentsService.instance.getPaymentsForPurchase(p.id!).then((list) {
                if (ctx2.mounted) {
                  setState(() {
                    installments = list;
                    isDialogLoading = false;
                  });
                }
              });
              // Return a dialog with loading indicator to maintain shape/context or just Center
              return const Center(child: CircularProgressIndicator());
            }

            final totalPaid = installments.fold<double>(0, (sum, i) => sum + i.amount);
            final totalAmount = (p.quantity ?? 0) * (p.cost ?? 0);
            final pending = totalAmount - totalPaid;
            final statusColor = pending <= 1 ? Colors.green : (totalPaid > 0 ? Colors.orange : Colors.red);
            final paymentStatus = pending <= 1 ? 'PAID' : (totalPaid > 0 ? 'PARTIAL' : 'UNPAID');

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gradient Header
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade800, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.companyName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.material,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _exportSinglePurchaseToExcel(p, installments),
                            icon: const Icon(Icons.download, color: Colors.white),
                            tooltip: 'Download Purchase',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic Details Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow('Unit Price', '₹${(p.cost ?? 0).toStringAsFixed(2)}'),
                                  _buildDetailRow('Quantity', '${p.quantity ?? 0}'),
                                  _buildDetailRow('Purchase Date', p.purchaseDate != null ? DateFormat('MMM dd, yyyy').format(p.purchaseDate!) : 'N/A'),
                                  if (p.notes != null && p.notes!.isNotEmpty)
                                    _buildDetailRow('Notes', p.notes!),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Payment Summary Section
                            Text(
                              'Payment Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow('Total Amount', '₹${totalAmount.toStringAsFixed(2)}'),
                                  _buildDetailRow('Total Paid', '₹${totalPaid.toStringAsFixed(2)}'),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    'Pending Amount',
                                    '₹${pending.toStringAsFixed(2)}',
                                    valueColor: pending > 1 ? Colors.red.shade700 : Colors.green.shade700,
                                  ),
                                  _buildDetailRow(
                                    'Status',
                                    paymentStatus,
                                    valueColor: statusColor,
                                  ),
                                  if (p.paymentDueDate != null && pending > 1) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Due: ${DateFormat('MMM dd, yyyy').format(p.paymentDueDate!)}',
                                            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Instructions / Payment History Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Installment History',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                if (pending > 1)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Add New ↓',
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            if (installments.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No payments recorded yet.',
                                    style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: installments.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final inst = installments[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade200),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat('MMM dd, yyyy').format(DateTime.parse(inst.paidAt)),
                                              style: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '₹${inst.amount.toStringAsFixed(2)}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade700),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 24),
                            
                            // Add Payment Section
                            if (pending > 1) ...[
                                Text(
                                  'Record New Payment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildModernTextField(
                                        controller: amountCtrl,
                                        label: 'Amount',
                                        icon: Icons.attach_money,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: ctx2,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setState(() => selectedDate = picked);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.blue.shade50),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 18, color: Colors.blue.shade600),
                                              const SizedBox(width: 8),
                                              Text(
                                                selectedDate == null 
                                                  ? 'Select Date' 
                                                  : DateFormat('MMM dd, yyyy').format(selectedDate!),
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue.shade600,
                                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                      ),
                                      child: IconButton(
                                        onPressed: () async {
                                          final amt = double.tryParse(amountCtrl.text);
                                          if (amt != null && selectedDate != null) {
                                            if (amt > pending + 1) { // Allowance for float delta
                                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount exceeds pending value!')));
                                               return;
                                            }
                                            
                                            // Optimistic Update
                                            final payment = PurchasePayment(
                                              purchaseId: p.id!,
                                              amount: amt,
                                              paidAt: DateFormat('yyyy-MM-dd').format(selectedDate!),
                                            );
                                            try {
                                              await PurchasePaymentsService.instance.addPayment(payment);
                                              // Refresh list
                                              final newList = await PurchasePaymentsService.instance.getPaymentsForPurchase(p.id!);
                                              if (ctx2.mounted) {
                                                 setState(() {
                                                   installments = newList;
                                                   amountCtrl.clear();
                                                   selectedDate = DateTime.now();
                                                 });
                                                 _loadPurchases(); // Update main dashboard counters
                                              }
                                            } catch(e) {
                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.add, color: Colors.white),
                                        tooltip: 'Add Payment',
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.blueGrey[600], fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? Colors.blueGrey[900], fontWeight: FontWeight.bold)),
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
        leading: Navigator.canPop(context) 
            ? const BackButton(color: Colors.white) 
            : const BackToDashboardButton(),
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
              'Purchases',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '${purchases.length} records',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download All Purchases (Excel)',
            onPressed: _exportAllPurchasesToExcel,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 16),
                        
                        // Search and Sort Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search vendors, materials...',
                                  prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade100),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: PopupMenuButton<String>(
                                icon: Icon(Icons.sort, color: Colors.blue.shade700),
                                tooltip: 'Sort',
                                onSelected: (val) {
                                  _sortBy = val;
                                  _sortPurchases();
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'date_desc', child: Text('Date: Newest')),
                                  const PopupMenuItem(value: 'date_asc', child: Text('Date: Oldest')),
                                  const PopupMenuItem(value: 'vendor_asc', child: Text('Vendor: A-Z')),
                                  const PopupMenuItem(value: 'vendor_desc', child: Text('Vendor: Z-A')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        WireCard(
                          title: 'Purchase Records',
                          titleColor: Colors.blue.shade900,
                          child:
                              purchases.isEmpty
                                  ? _buildEmptyState()
                                  : _buildPurchaseTable(),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
      floatingActionButton: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          onPressed: () => _showPurchaseFormDialog(),
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

  Widget _buildSummaryCards() {
    final paidCount = purchases.where((p) => p.paymentStatus == 'paid').length;
    final pendingCount = purchases.length - paidCount;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Paid Purchases',
            count: paidCount,
            color: Colors.green,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: 'Pending Purchases',
            count: pendingCount,
            color: Colors.orange,
            icon: Icons.pending_actions,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({required String title, required int count, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 8),
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[900])),
        ],
      ),
    );
  }

  Widget _buildPurchaseTable() {
    // Filter logic
    final query = _searchController.text.toLowerCase();
    final displayed = purchases.where((p) {
      final vendor = p.companyName.toLowerCase();
      final material = p.material.toLowerCase();
      return vendor.contains(query) || material.contains(query);
    }).toList();

    if (displayed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(child: Text('No matching records found')),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
        columns: const [
          DataColumn(label: Text('View', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))), 
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pending', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: displayed.map((p) {
          final total = (p.quantity ?? 0) * (p.cost ?? 0);
          final paid = _paidAmounts[p.id] ?? 0.0;
          final pending = total - paid;
          final statusColor = pending <= 0 ? Colors.green : (paid > 0 ? Colors.orange : Colors.red);
          final statusText = pending <= 0 ? 'PAID' : (paid > 0 ? 'PARTIAL' : 'UNPAID');

          return DataRow(cells: [
             DataCell(
              IconButton(
                icon: const Icon(Icons.visibility, color: Colors.blue),
                onPressed: () => _showPurchaseDetailsDialog(p),
                tooltip: 'View Details',
              ),
            ),
            DataCell(Text(p.companyName, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(p.material)),
            DataCell(Text('${p.quantity ?? 0}')),
            DataCell(Text(p.purchaseDate != null ? DateFormat('MM/dd/yy').format(p.purchaseDate!) : '')),
            DataCell(Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('₹${paid.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500))),
            DataCell(Text('₹${pending.toStringAsFixed(2)}', style: TextStyle(color: pending > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            DataCell(Text(p.paymentDueDate != null ? DateFormat('MM/dd/yy').format(p.paymentDueDate!) : '-')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                    onPressed: () => _showPurchaseFormDialog(existing: p),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deletePurchase(p),
                    tooltip: 'Delete',
                  ),
                ],
              )
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No purchases yet', style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
