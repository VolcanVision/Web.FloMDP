import 'package:flutter/material.dart';
import '../widgets/back_to_dashboard.dart';

// Lightweight replacement for removed RecipeItem model (table dropped from DB)
class LineItem {
  String product;
  double costPerUnit;
  double requiredQty;
  LineItem({
    required this.product,
    required this.costPerUnit,
    required this.requiredQty,
  });
  double get totalCost => costPerUnit * requiredQty;
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  _CalculatorPageState createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _productController = TextEditingController();
  final _costPerUnitController = TextEditingController();
  final _requiredController = TextEditingController();
  final _quantityProducedController = TextEditingController();
  final _requiredQuantityController = TextEditingController();
  final _totalCostController = TextEditingController();

  List<LineItem> recipeItems = [];

  void addRecipeItem() {
    if (_productController.text.isNotEmpty &&
        _costPerUnitController.text.isNotEmpty &&
        _requiredController.text.isNotEmpty) {
      setState(() {
        recipeItems.add(
          LineItem(
            product: _productController.text,
            costPerUnit: double.tryParse(_costPerUnitController.text) ?? 0,
            requiredQty: double.tryParse(_requiredController.text) ?? 0,
          ),
        );
      });
      _calculateTotalCost();
      _productController.clear();
      _costPerUnitController.clear();
      _requiredController.clear();
    }
  }

  void deleteRecipeItem(int index) {
    setState(() {
      if (index < recipeItems.length) recipeItems.removeAt(index);
    });
    _calculateTotalCost();
  }

  void _calculateTotalCost() {
    double quantityProduced =
        double.tryParse(_quantityProducedController.text) ?? 0;
    double requiredQuantity =
        double.tryParse(_requiredQuantityController.text) ?? 0;

    double costPerUnitProduced =
        quantityProduced > 0 ? recipeTotalCost / quantityProduced : 0;
    double totalCostForRequired = costPerUnitProduced * requiredQuantity;

    setState(() {
      _totalCostController.text = totalCostForRequired.toStringAsFixed(2);
    });
  }

  double get recipeTotalCost =>
      recipeItems.fold(0, (sum, item) => sum + item.totalCost);

  double get _computedProducedQuantity =>
      double.tryParse(_quantityProducedController.text) ?? 0.0;

  double get _computedRequiredQuantity =>
      double.tryParse(_requiredQuantityController.text) ?? 0.0;

  double get _computedCostPerUnit {
    final produced = _computedProducedQuantity;
    if (produced <= 0) return 0.0;
    return recipeTotalCost / produced;
  }

  double get _computedCostForRequired {
    final required = _computedRequiredQuantity;
    return _computedCostPerUnit * required;
  }

  void _showFullBill() {
    final produced = double.tryParse(_quantityProducedController.text) ?? 0;
    final required = double.tryParse(_requiredQuantityController.text) ?? 0;
    final costPerUnit = produced > 0 ? recipeTotalCost / produced : 0.0;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text('Full Cost Bill'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line items
                  ...recipeItems.map((it) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              it.product,
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${it.requiredQty.toStringAsFixed(2)} x \$${it.costPerUnit.toStringAsFixed(2)}',
                          ),
                          SizedBox(width: 12),
                          Text(
                            '\$${it.totalCost.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  Divider(),
                  _buildCostRow(
                    'Subtotal',
                    '\$${recipeTotalCost.toStringAsFixed(2)}',
                    Colors.black87,
                  ),
                  SizedBox(height: 8),
                  _buildCostRow(
                    'Quantity Produced',
                    '${produced.toStringAsFixed(2)} units',
                    Colors.black87,
                  ),
                  _buildCostRow(
                    'Cost per Unit',
                    '\$${costPerUnit.toStringAsFixed(4)}',
                    Colors.black87,
                  ),
                  if (required > 0) ...[
                    Divider(),
                    _buildCostRow(
                      'Required Quantity',
                      '${required.toStringAsFixed(2)} units',
                      Colors.black87,
                    ),
                    _buildCostRow(
                      'Cost for Required Qty',
                      '\$${(costPerUnit * required).toStringAsFixed(2)}',
                      Colors.black87,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildCostRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _productController.dispose();
    _costPerUnitController.dispose();
    _requiredController.dispose();
    _quantityProducedController.dispose();
    _requiredQuantityController.dispose();
    _totalCostController.dispose();
    super.dispose();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Cost Calculator',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Calculate production costs',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [const BackToDashboardButton()],
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
            colors: [Colors.blue.shade50, Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Add Ingredient Section
              _buildSectionHeader('Add Ingredient'),
              const SizedBox(height: 12),
              _buildIngredientForm(),
              const SizedBox(height: 24),

              // Ingredients List
              if (recipeItems.isNotEmpty) ...[
                _buildSectionHeader('Recipe Ingredients'),
                const SizedBox(height: 12),
                _buildIngredientsList(),
                const SizedBox(height: 24),
              ],

              // Calculation Section
              _buildSectionHeader('Cost Calculation'),
              const SizedBox(height: 12),
              _buildCalculationForm(),
              const SizedBox(height: 24),

              // Results Section
              if (_computedCostForRequired > 0) ...[
                _buildSectionHeader('Results'),
                const SizedBox(height: 12),
                _buildResultsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          // Product Name - Full width
          _buildModernTextField(
            controller: _productController,
            label: 'Product Name',
            icon: Icons.inventory_2,
          ),
          const SizedBox(height: 12),
          // Cost and Quantity in a row
          Row(
            children: [
              Expanded(
                child: _buildModernTextField(
                  controller: _costPerUnitController,
                  label: 'Cost per Unit',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _calculateTotalCost(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModernTextField(
                  controller: _requiredController,
                  label: 'Required Qty',
                  icon: Icons.scale,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _calculateTotalCost(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Add button - Full width
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: addRecipeItem,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Ingredient',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue.shade700, size: 18),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          labelStyle: TextStyle(color: Colors.blue.shade800, fontSize: 13),
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  Widget _buildIngredientsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Column(
        children: [
          // Table Header
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
                Icon(Icons.table_chart, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recipe Table (${recipeItems.length} items)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          // Table Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Product',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Cost/Unit',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total Cost',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 40), // Space for delete button
              ],
            ),
          ),
          // Table Rows
          ...recipeItems.asMap().entries.map((entry) {
            int index = entry.key;
            LineItem item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: index == recipeItems.length - 1 ? 0 : 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      item.product,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${item.costPerUnit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.requiredQty.toStringAsFixed(2),
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${item.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: () => deleteRecipeItem(index),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade600,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          // Table Footer with Total and Cost/Unit
          if (recipeItems.isNotEmpty)
            Column(
              children: [
                // Total Row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.blue.shade100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // give minimal space for intermediate columns
                      Expanded(
                        flex: 1,
                        child: Text(
                          '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // give more room for the total value
                      Expanded(
                        flex: 4,
                        child: Text(
                          '\$${recipeTotalCost.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12), // reduced spacer for alignment
                    ],
                  ),
                ),
                // Cost/Unit Row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.blue.shade100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'COST/UNIT',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          _computedProducedQuantity > 0
                              ? '\$${(_computedCostPerUnit).toStringAsFixed(4)}'
                              : '\$0.0000',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12), // reduced spacer for alignment
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCalculationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          _buildModernTextField(
            controller: _quantityProducedController,
            label: 'Quantity Produced',
            icon: Icons.production_quantity_limits,
            keyboardType: TextInputType.number,
            onChanged: (value) => _calculateTotalCost(),
          ),
          const SizedBox(height: 12),
          _buildModernTextField(
            controller: _requiredQuantityController,
            label: 'Required Qty',
            icon: Icons.shopping_cart,
            keyboardType: TextInputType.number,
            onChanged: (value) => _calculateTotalCost(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Cost Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            'Recipe Total Cost',
            '\$${recipeTotalCost.toStringAsFixed(2)}',
            Colors.blue.shade700,
          ),
          if (_computedRequiredQuantity > 0)
            _buildResultRow(
              'Total Cost for Required',
              '\$${_computedCostForRequired.toStringAsFixed(2)}',
              Colors.blue.shade800,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showFullBill,
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text(
                'View Full Bill',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
