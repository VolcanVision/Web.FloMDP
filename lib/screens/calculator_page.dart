import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/excel_export_service.dart';
import '../widgets/back_to_dashboard.dart';

// --- Reusable "Wire" Card with vertical accent bar ---
class VerticalWireCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? icon; // Optional icon next to title
  final Color accentColor;

  const VerticalWireCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accentColor = const Color(0xFF1565C0), // Default blue
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            // Light shadow for depth
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  // Target Settings (Always KG)
  double _targetQty = 0.00; // Default from screenshot example
  final TextEditingController _targetQtyController = TextEditingController(
    text: '',
  );

  // Ingredient/Required Unit Toggle (kg vs g) -> Only for "Add Ingredient" UI logic
  bool _isIngredientKg = true; // true = kg, false = g
  bool _isRequiredKg = true; // true = kg, false = lt/kg

  // Ingredients
  final List<Map<String, dynamic>> _ingredients = [];
  final TextEditingController _ingNameController = TextEditingController();
  final TextEditingController _ingCostController =
      TextEditingController(); // Cost per KG
  final TextEditingController _ingPercentController = TextEditingController();
  final TextEditingController _ingMassController = TextEditingController();

  // Variable Costs (Per Unit/KG) - ALWAYS IN KG
  final List<Map<String, dynamic>> _variableExtras = [];
  final TextEditingController _varCostNameCtrl = TextEditingController();
  final TextEditingController _varCostAmtCtrl = TextEditingController();

  // Fixed Costs (Flat)
  final List<Map<String, dynamic>> _fixedExtras = [];
  final TextEditingController _fixedCostNameCtrl = TextEditingController();
  final TextEditingController _fixedCostAmtCtrl = TextEditingController();

  // Required Output
  final TextEditingController _requiredQtyController = TextEditingController(
    text: '',
  );

  @override
  void dispose() {
    _targetQtyController.dispose();
    _ingNameController.dispose();
    _ingCostController.dispose();
    _ingPercentController.dispose();
    _ingMassController.dispose();
    _varCostNameCtrl.dispose();
    _varCostAmtCtrl.dispose();
    _fixedCostNameCtrl.dispose();
    _fixedCostAmtCtrl.dispose();
    _requiredQtyController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---

  // Convert displayed ingredient mass to internal mass (kg)
  double _parseIngMassToKg(String text) {
    double val = double.tryParse(text) ?? 0;
    return _isIngredientKg ? val : val / 1000.0;
  }

  // Convert internal mass (kg) to displayed ingredient mass
  double _convertKgToIngDisplay(double kg) {
    return _isIngredientKg ? kg : kg * 1000.0;
  }

  // Convert displayed required qty to kg
  double _parseReqToKg(String text) {
    double val = double.tryParse(text) ?? 0;
    return val; // In this design, assuming input is always treated as base unit for calculation
  }

  void _updateMassFromPercent(String val) {
    double percent = double.tryParse(val) ?? 0;
    double massKg = (_targetQty * percent) / 100.0;
    double displayMass = _convertKgToIngDisplay(massKg);
    _ingMassController.text = displayMass.toStringAsFixed(3);
  }

  void _updatePercentFromMass(String val) {
    double massKg = _parseIngMassToKg(val);
    if (_targetQty == 0) return;
    double percent = (massKg / _targetQty) * 100.0;
    _ingPercentController.text = percent.toStringAsFixed(2);
  }

  void _addIngredient() {
    if (_ingNameController.text.isEmpty) return;
    double costPerKg = double.tryParse(_ingCostController.text) ?? 0;
    double percent = double.tryParse(_ingPercentController.text) ?? 0;
    double massKg = _parseIngMassToKg(_ingMassController.text);

    // Auto-calculate missing values
    if (percent == 0 && massKg > 0 && _targetQty > 0) {
      percent = (massKg / _targetQty) * 100;
    } else if (massKg == 0 && percent > 0) {
      massKg = (_targetQty * percent) / 100;
    }

    setState(() {
      _ingredients.add({
        'name': _ingNameController.text,
        'cost_per_kg': costPerKg,
        'percent': percent,
        'mass_kg': massKg,
      });
      _ingNameController.clear();
      _ingCostController.clear();
      _ingPercentController.clear();
      _ingMassController.clear();
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _addVariableCost() {
    if (_varCostNameCtrl.text.isEmpty) return;
    double amount = double.tryParse(_varCostAmtCtrl.text) ?? 0; // Always in KG

    setState(() {
      _variableExtras.add({
        'name': _varCostNameCtrl.text,
        'amount': amount, // Store as per KG
      });
      _varCostNameCtrl.clear();
      _varCostAmtCtrl.clear();
    });
  }

  void _removeVariableCost(int index) {
    setState(() => _variableExtras.removeAt(index));
  }

  void _addFixedCost() {
    if (_fixedCostNameCtrl.text.isEmpty) return;
    double amount = double.tryParse(_fixedCostAmtCtrl.text) ?? 0;
    setState(() {
      _fixedExtras.add({'name': _fixedCostNameCtrl.text, 'amount': amount});
      _fixedCostNameCtrl.clear();
      _fixedCostAmtCtrl.clear();
    });
  }

  void _removeFixedCost(int index) {
    setState(() => _fixedExtras.removeAt(index));
  }

  // --- Calculations ---

  double get _totalRecipeCost {
    double total = 0;
    for (var ing in _ingredients) {
      total += (ing['mass_kg'] as double) * (ing['cost_per_kg'] as double);
    }
    return total;
  }

  // Total Required Quantity (sum of all mass_kg)
  double get _totalRequiredQty {
    double total = 0;
    for (var ing in _ingredients) {
      total += (ing['mass_kg'] as double);
    }
    return total;
  }

  double get _recipeCostPerKg {
    if (_targetQty == 0) return 0;
    return _totalRecipeCost / _targetQty;
  }

  double get _totalVariableExtrasPerKg {
    double total = 0;
    for (var extra in _variableExtras) {
      total += (extra['amount'] as double);
    }
    return total;
  }

  double get _totalFixedExtras {
    double total = 0;
    for (var extra in _fixedExtras) {
      total += (extra['amount'] as double);
    }
    return total;
  }

  // Combined Cost per Unit (y+x)
  double get _combinedCostPerUnit {
    return _recipeCostPerKg + _totalVariableExtrasPerKg;
  }

  // Cost for Required Qty
  double get _costForRequiredQty {
    double reqKg = _parseReqToKg(_requiredQtyController.text);
    return reqKg * _combinedCostPerUnit;
  }

  double get _grandTotal {
    return _costForRequiredQty + _totalFixedExtras;
  }

  // --- Widgets ---

  // Custom Input Field with Icon styling from screenshot
  Widget _buildField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool isNumber = false,
    Function(String)? onChanged,
    String? suffix,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: onChanged,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon:
              icon != null
                  ? Icon(icon, color: Colors.blue.shade700, size: 20)
                  : null,
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixText: suffix,
        ),
      ),
    );
  }

  // The custom "kg / lt" dropdown pill
  Widget _buildUnitDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _isIngredientKg ? 'kg' : 'g',
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          onChanged: (val) {
            setState(() {
              _isIngredientKg = val == 'kg';
            });
          },
          items: const [
            DropdownMenuItem(value: 'kg', child: Text('kg / lt')),
            DropdownMenuItem(value: 'g', child: Text('g / ml')),
          ],
        ),
      ),
    );
  }

  // Recipe Table
  Widget _buildRecipeTable() {
    if (_ingredients.isEmpty) {
      return Center(
        child: Text(
          'No ingredients added',
          style: TextStyle(
            color: Colors.grey[400],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text(
                  '  Product',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'Cost/kg',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'Required',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              SizedBox(width: 32), // Spacer for delete icon
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Rows
        ..._ingredients.asMap().entries.map((e) {
          final i = e.value;
          final idx = e.key;
          final totalCost =
              (i['mass_kg'] as double) * (i['cost_per_kg'] as double);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    i['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${i['cost_per_kg'].toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    i['mass_kg'].toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${totalCost.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    onPressed: () => _removeIngredient(idx),
                  ),
                ),
              ],
            ),
          );
        }),
        const Divider(height: 24),
        // Totals Row - aligned with columns
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '  TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '₹${_recipeCostPerKg.toStringAsFixed(2)}/kg',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${_totalRequiredQty.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '₹${_totalRecipeCost.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              const SizedBox(
                width: 32,
              ), // Spacer to align with delete icon column
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50, // Matches standard app background
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Target Quantity
            VerticalWireCard(
              title: 'Target Quantity',
              child: _buildField(
                _targetQtyController,
                'Target Quantity (kg)',
                icon: Icons.scale,
                isNumber: true,
                onChanged:
                    (val) =>
                        setState(() => _targetQty = double.tryParse(val) ?? 0),
              ),
            ),
            const SizedBox(height: 20),

            // Add Ingredient
            VerticalWireCard(
              title: 'Add Ingredient',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(
                    _ingNameController,
                    'Product Name',
                    icon: Icons.delete_outline,
                  ), // Using standard bin icon from image as generic product icon
                  _buildField(
                    _ingCostController,
                    'Cost per kg',
                    icon: Icons.attach_money,
                    isNumber: true,
                  ),
                  _buildField(
                    _ingPercentController,
                    '% of Target',
                    icon: Icons.percent,
                    isNumber: true,
                    onChanged: _updateMassFromPercent,
                  ),
                  _buildField(
                    _ingMassController,
                    'Mass',
                    icon: Icons.scale,
                    isNumber: true,
                    onChanged: _updatePercentFromMass,
                  ),

                  // Unit Dropdown + Add Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildUnitDropdown(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addIngredient,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF1565C0,
                            ), // Blue color from screenshot
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            'Add ingredient',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recipe Ingredients Table
            VerticalWireCard(
              title: 'Recipe Ingredients',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.table_chart,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recipe Table (${_ingredients.length} Items)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRecipeTable(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Extra Costs
            VerticalWireCard(
              title: 'Extra Costs',
              accentColor: Colors.blue.shade700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Variable Costs Input
                  const Text(
                    'Add Per-Unit Extra (Process Cost)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    _varCostNameCtrl,
                    'Name',
                    icon: Icons.label_outline,
                  ),
                  _buildField(
                    _varCostAmtCtrl,
                    'Amount per kg',
                    icon: Icons.attach_money,
                    isNumber: true,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _addVariableCost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1976D2,
                        ), // Lighter blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Fixed Costs Input
                  const Text(
                    'Add Fixed Extra (one-time)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    _fixedCostNameCtrl,
                    'Name',
                    icon: Icons.label_outline,
                  ),
                  _buildField(
                    _fixedCostAmtCtrl,
                    'Amount',
                    icon: Icons.attach_money,
                    isNumber: true,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _addFixedCost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),

                  const Divider(height: 32),

                  // Lists of added extras
                  if (_variableExtras.isNotEmpty) ...[
                    const Text(
                      'Per-Unit Extras:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._variableExtras.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.value['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '₹${(e.value['amount'] as double).toStringAsFixed(2)} per kg',
                                  style: TextStyle(color: Colors.blue.shade700),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _removeVariableCost(e.key),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade400,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Per-Unit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${_totalVariableExtrasPerKg.toStringAsFixed(2)} per kg',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_fixedExtras.isNotEmpty) ...[
                    const Text(
                      'Fixed Extras:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._fixedExtras.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.value['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '₹${(e.value['amount'] as double).toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.blue.shade700),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _removeFixedCost(e.key),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade400,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Fixed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${_totalFixedExtras.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Combined Cost/kg:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        Text(
                          '₹${_combinedCostPerUnit.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cost Calculation Input
            VerticalWireCard(
              title: 'Cost Calculation',
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildField(
                      _requiredQtyController,
                      'Required Qty',
                      icon: Icons.shopping_cart,
                      isNumber: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.only(
                        bottom: 12,
                      ), // aligns with field
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _isRequiredKg ? 'kg' : 'lt',
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          onChanged:
                              (v) =>
                                  setState(() => _isRequiredKg = (v == 'kg')),
                          items: const [
                            DropdownMenuItem(
                              value: 'kg',
                              child: Text(
                                'kg / lt',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'lt',
                              child: Text(
                                'g / ml',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Results Card (Blue)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFD6E8FA,
                ), // Light blue background like screenshot
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Cost Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Summary Rows
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recipe Total Cost',
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_totalRecipeCost.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fixed Extras (w)',
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_totalFixedExtras.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Cost for Required',
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showFullBillDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2), // Blue
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.receipt, size: 18),
                          label: const Text(
                            'View Full Bill',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _exportBillToExcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047), // Green
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text(
                            'Download Excel',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showFullBillDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: const Color(0xFFF0F4FC), // Very light blue/grey
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: Colors.blue.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Full Cost Bill',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ingredients List
                          if (_ingredients.isNotEmpty)
                            ..._ingredients.map((ing) {
                              final total =
                                  (ing['mass_kg'] as double) *
                                  (ing['cost_per_kg'] as double);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ing['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${ing['mass_kg']} x ₹${ing['cost_per_kg']}   ₹${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 24),

                          _buildBillRow(
                            'Total Required Qty',
                            '${_totalRequiredQty.toStringAsFixed(2)} kg',
                            isBold: true,
                          ),
                          const SizedBox(height: 12),
                          _buildBillRow(
                            'Subtotal (Ingredients)',
                            '₹${_totalRecipeCost.toStringAsFixed(2)}',
                            isBold: true,
                          ),
                          const SizedBox(height: 12),
                          _buildBillRow(
                            'Quantity Produced',
                            '${_targetQty.toStringAsFixed(2)} kg',
                            isBold: true,
                          ),
                          const SizedBox(height: 12),
                          _buildBillRow(
                            'Ingredient Cost per Unit',
                            '₹${_recipeCostPerKg.toStringAsFixed(4)}',
                            isBold: true,
                          ),

                          const Divider(height: 32),
                          const Text(
                            'Per-Unit Extra Costs (Processes)',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_variableExtras.isNotEmpty)
                            ..._variableExtras.map(
                              (e) => _buildBillRow(
                                e['name'],
                                '₹${(e['amount'] as double).toStringAsFixed(2)} per kg',
                                isBold: true,
                              ),
                            ),

                          const SizedBox(height: 8),
                          _buildBillRow(
                            'Total Per-Unit Extras',
                            '₹${_totalVariableExtrasPerKg.toStringAsFixed(4)} pe...',
                            isBold: true,
                            valueColor: Colors.blue.shade700,
                          ),

                          const SizedBox(height: 16),
                          // Summary Box-ish feel
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _buildBillRow(
                              'Combined Cost per Unit (y+x)',
                              '₹${_combinedCostPerUnit.toStringAsFixed(4)}',
                              isBold: true,
                              valueColor: Colors.blue.shade800,
                            ),
                          ),

                          const Divider(height: 32),
                          const Text(
                            'Fixed Extra Costs (Transportation, etc.)',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_fixedExtras.isNotEmpty)
                            ..._fixedExtras.map(
                              (e) => _buildBillRow(
                                e['name'],
                                '₹${(e['amount'] as double).toStringAsFixed(2)}',
                                isBold: true,
                              ),
                            ),

                          const SizedBox(height: 8),
                          _buildBillRow(
                            'Total Fixed Extras (w)',
                            '₹${_totalFixedExtras.toStringAsFixed(2)}',
                            isBold: true,
                            valueColor: Colors.blue.shade700,
                          ),

                          const Divider(height: 32),

                          _buildBillRow(
                            'Required Quantity (R)',
                            '${_requiredQtyController.text} kg',
                            isBold: true,
                          ),
                          const SizedBox(height: 8),
                          _buildBillRow(
                            'Cost per Unit (y+x)',
                            '₹${_combinedCostPerUnit.toStringAsFixed(4)} pe...',
                            isBold: true,
                          ),

                          const SizedBox(height: 16),
                          _buildBillRow(
                            'Cost for Required Qty:',
                            '₹${(_costForRequiredQty + _totalFixedExtras).toStringAsFixed(2)}',
                            isBold: true,
                            fontSize: 18,
                          ),
                          // Note: The screenshot shows Rx(v+x) which implies fixed costs might be handled differently or added at the end.
                          // I'm assuming Grand Total = (ReqQty * CombinedUnit) + Fixed.
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildBillRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.black87,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Future<void> _exportBillToExcel() async {
    try {
      final reqKg = _parseReqToKg(_requiredQtyController.text);
      final headers = ['Description', 'Value'];
      final rows = <List<dynamic>>[
        ['Cost Calculator Bill', ''],
        [
          'Generated Date',
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        ],
        ['', ''],
        ['INGREDIENTS', ''],
      ];

      for (var ing in _ingredients) {
        rows.add([
          '${ing['name']} (${ing['percent'].toStringAsFixed(1)}%)',
          '₹${((ing['mass_kg'] as double) * (ing['cost_per_kg'] as double)).toStringAsFixed(2)}',
        ]);
      }

      rows.add([
        'Total Required Qty',
        '${_totalRequiredQty.toStringAsFixed(2)} kg',
      ]);
      rows.add([
        'Subtotal (Ingredients)',
        '₹${_totalRecipeCost.toStringAsFixed(2)}',
      ]);
      rows.add(['Quantity Produced', '${_targetQty.toStringAsFixed(2)} kg']);
      rows.add([
        'Ingredient Cost per KG',
        '₹${_recipeCostPerKg.toStringAsFixed(4)}',
      ]);
      rows.add(['', '']);
      rows.add(['VARIABLE COSTS (Per KG)', '']);

      for (var extra in _variableExtras) {
        rows.add([
          extra['name'],
          '₹${extra['amount'].toStringAsFixed(2)} / kg',
        ]);
      }
      rows.add([
        'Total Variable Costs per KG',
        '₹${_totalVariableExtrasPerKg.toStringAsFixed(4)}',
      ]);
      rows.add(['', '']);
      rows.add([
        'Combined Cost per KG',
        '₹${_combinedCostPerUnit.toStringAsFixed(4)}',
      ]);
      rows.add(['Required Quantity', '${_requiredQtyController.text} kg']);
      rows.add([
        'Cost for Required Qty',
        '₹${_costForRequiredQty.toStringAsFixed(2)}',
      ]);
      rows.add(['', '']);
      rows.add(['FIXED COSTS', '']);
      for (var extra in _fixedExtras) {
        rows.add([extra['name'], '₹${extra['amount'].toStringAsFixed(2)}']);
      }
      rows.add([
        'Total Fixed Costs',
        '₹${_totalFixedExtras.toStringAsFixed(2)}',
      ]);

      rows.add(['', '']);
      rows.add(['GRAND TOTAL', '₹${_grandTotal.toStringAsFixed(2)}']);

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName:
            'cost_calculator_bill_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
