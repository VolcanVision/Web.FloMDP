import 'package:flutter/material.dart';
import '../../widgets/wire_card.dart';
import '../../models/purchase.dart';
import '../../services/purchases_service.dart';
import '../../widgets/back_to_dashboard.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      purchases = await PurchasesService().fetchAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading purchases: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddPurchaseDialog() async {
    _vendorController.clear();
    _itemController.clear();
    _quantityController.clear();
    _priceController.clear();
    _notesController.clear();
    _selectedCategory = 'Raw Material';
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New Purchase',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add purchase details',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
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
                  child: SingleChildScrollView(
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
                            value: _selectedCategory,
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
                              setState(() => _selectedCategory = value!);
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
                                    await _createPurchase(ctx);
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
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_shopping_cart, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Create Purchase',
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

  Future<void> _createPurchase(BuildContext ctx) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      final purchase = Purchase(
        companyName: _vendorController.text.trim(),
        material: _itemController.text.trim(),
        quantity: double.tryParse(_quantityController.text),
        cost: double.tryParse(_priceController.text),
        notes:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
        purchaseDate: DateTime.now(),
        paymentStatus: 'unpaid',
      );
      final result = await PurchasesService().create(purchase);
      if (!mounted) return;
      Navigator.of(ctx).pop();
      if (result != null) {
        await _loadPurchases();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create purchase'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildPurchaseTile(Purchase p) {
    final statusColor = (p.paymentStatus == 'paid') ? Colors.green : Colors.red;
    return InkWell(
      onTap: () {}, // Could show details dialog
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 72,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListTile(
                title: Text(
                  p.companyName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${p.material} • Qty ${p.quantity ?? 0}'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${((p.quantity ?? 0) * (p.cost ?? 0)).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Chip(
                    label: Text(
                      p.paymentStatus == 'paid' ? 'PAID' : 'UNPAID',
                      style: TextStyle(color: statusColor),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: const BackToDashboardButton(),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Purchases',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${purchases.length} records',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
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
                        WireCard(
                          title: 'Purchases (${purchases.length})',
                          titleColor: Colors.blue.shade900,
                          child:
                              purchases.isEmpty
                                  ? SizedBox(
                                    height: 160,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.shopping_cart_outlined,
                                            size: 56,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No purchases yet',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  : Column(
                                    children:
                                        purchases
                                            .map(_buildPurchaseTile)
                                            .toList(),
                                  ),
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
          onPressed: _showAddPurchaseDialog,
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
    _vendorController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
