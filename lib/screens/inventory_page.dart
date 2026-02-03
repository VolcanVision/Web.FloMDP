import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_item.dart';
import '../models/inventory_addition.dart';
import '../models/inventory_consumption.dart';
import '../services/excel_export_service.dart';
import '../services/inventory_service.dart';
import '../services/supabase_service.dart';
import '../widgets/back_to_dashboard.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with SingleTickerProviderStateMixin {
  Color get _blue => Colors.blue.shade600;

  List<InventoryItem> _allItems = [];
  String? _selectedStatusFilter;
  late TabController _tabController;

  final List<String> _statusOptions = [
    'All',
    'fresh',
    'returned',
    'recycled',
    'spare',
    'used',
  ];
  final List<String> _categories = [
    'Raw Materials',
    'Finished Goods',
    'Additives',
    'Spare Parts',
  ];

  bool _loading = false;
  String? _error;

  // For tracking editable fields (we'll use quantity for 'total', name for 'material')
  double _getTotal(InventoryItem item) => item.quantity;
  int _getRequired(InventoryItem item) => 0; // default zero as requested
  int _getMinQty(InventoryItem item) => item.minQuantity ?? 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadInventory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = SupabaseService();

      // Ensure authentication. If anonymous sign-in fails, continue unauthenticated
      // so the UI can display service-specific errors (e.g. RLS). This avoids
      // throwing here and crashing the load flow.
      if (!service.isAuthenticated) {
        print('[Inventory] Not authenticated, attempting anonymous sign-in...');
        final signedIn = await service.signInAnonymously();
        if (!signedIn) {
          // Log and continue — many projects disable anonymous sign-in. The
          // Supabase service methods will return RLS errors if inserts/selects
          // are blocked; those are surfaced in the UI via service.lastInventoryError.
          print(
            '[Inventory] Anonymous sign-in failed; proceeding unauthenticated.',
          );
        } else {
          print('[Inventory] Authentication successful');
        }
      } else {
        print('[Inventory] Already authenticated');
      }

      // Fetch inventory items
      print('[Inventory] Fetching inventory items...');
      _allItems = await service.getInventoryItems();
      print('[Inventory] Fetched ${_allItems.length} items');

      // Check for service-specific errors
      if (_allItems.isEmpty && service.lastInventoryError != null) {
        _error = 'Database error: ${service.lastInventoryError}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(service.lastInventoryError!),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('[Inventory] Error loading inventory: $e');
      _error = 'Failed to load inventory: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Show export options dialog
  void _showExportOptionsDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.download, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Text('Export Inventory'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.category, color: Colors.blue.shade600),
                  title: const Text('Export Current Category'),
                  subtitle: Text(_categories[_tabController.index]),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportInventoryToExcel(
                      category: _categories[_tabController.index],
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.inventory_2,
                    color: Colors.green.shade600,
                  ),
                  title: const Text('Export All Inventory'),
                  subtitle: const Text('All categories'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportInventoryToExcel();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.warning, color: Colors.orange.shade600),
                  title: const Text('Export Low Stock Items'),
                  subtitle: const Text('Items below minimum quantity'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportLowStockToExcel();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.add_circle, color: Colors.green.shade600),
                  title: const Text('Export Additions History'),
                  subtitle: const Text('All material additions with dates'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportAdditionsHistory();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.remove_circle,
                    color: Colors.orange.shade600,
                  ),
                  title: const Text('Export Consumptions History'),
                  subtitle: const Text('All material consumptions with dates'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportConsumptionsHistory();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  /// Export additions history to CSV
  Future<void> _exportAdditionsHistory() async {
    try {
      final inventoryService = InventoryService();
      final additions = await inventoryService.fetchAdditions();

      if (additions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No addition records found!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final headers = [
        'Date',
        'Item Name',
        'Quantity',
        'Supplier',
        'Notes',
        'Created At',
      ];

      final List<List<dynamic>> rows =
          additions.map((a) {
            return [
              DateFormat('dd/MM/yyyy').format(a.additionDate),
              a.itemName,
              a.quantity.toString(),
              a.supplier ?? '',
              a.notes ?? '',
              a.createdAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(a.createdAt!)
                  : '',
            ];
          }).toList();

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName:
            'inventory_additions_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Additions history exported successfully!'),
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

  /// Export consumptions history to CSV
  Future<void> _exportConsumptionsHistory() async {
    try {
      final inventoryService = InventoryService();
      final consumptions = await inventoryService.fetchConsumptions();

      if (consumptions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No consumption records found!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final headers = [
        'Date',
        'Item Name',
        'Quantity',
        'Purpose',
        'Batch No',
        'Notes',
        'Created At',
      ];

      final List<List<dynamic>> rows =
          consumptions.map((c) {
            return [
              DateFormat('dd/MM/yyyy').format(c.consumptionDate),
              c.itemName,
              c.quantity.toString(),
              c.purpose ?? '',
              c.batchNo ?? '',
              c.notes ?? '',
              c.createdAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(c.createdAt!)
                  : '',
            ];
          }).toList();

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName:
            'inventory_consumptions_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consumptions history exported successfully!'),
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

  /// Show transaction history dialog with tabs for additions and consumptions
  void _showTransactionHistoryDialog() {
    showDialog(context: context, builder: (ctx) => _TransactionHistoryDialog());
  }

  /// Export inventory to Excel/CSV
  Future<void> _exportInventoryToExcel({String? category}) async {
    try {
      final headers = [
        'Name',
        'Category',
        'Type/Status',
        'Quantity',
        'Min Quantity',
        'Stock Status',
      ];

      List<InventoryItem> itemsToExport;
      if (category != null) {
        itemsToExport = _getFilteredItems(category);
      } else {
        itemsToExport = _allItems;
      }

      final List<List<dynamic>> rows =
          itemsToExport.map((item) {
            final isLowStock =
                (item.minQuantity ?? 0) > 0 &&
                item.quantity <= (item.minQuantity ?? 0);
            return [
              item.name,
              item.category,
              item.type,
              item.quantity.toString(),
              (item.minQuantity ?? 0).toString(),
              isLowStock ? 'LOW STOCK' : 'OK',
            ];
          }).toList();

      final fileName =
          category != null
              ? 'inventory_${category.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}'
              : 'inventory_all_${DateFormat('yyyyMMdd').format(DateTime.now())}';

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inventory exported successfully!'),
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

  /// Export low stock items to Excel/CSV
  Future<void> _exportLowStockToExcel() async {
    try {
      final headers = [
        'Name',
        'Category',
        'Type/Status',
        'Current Quantity',
        'Min Quantity',
        'Shortage',
      ];

      final lowStockItems =
          _allItems.where((item) {
            final minQty = item.minQuantity ?? 0;
            return minQty > 0 && item.quantity <= minQty;
          }).toList();

      if (lowStockItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No low stock items found!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final List<List<dynamic>> rows =
          lowStockItems.map((item) {
            final shortage = (item.minQuantity ?? 0) - item.quantity.toInt();
            return [
              item.name,
              item.category,
              item.type,
              item.quantity.toString(),
              (item.minQuantity ?? 0).toString(),
              shortage > 0 ? shortage.toString() : '0',
            ];
          }).toList();

      await ExcelExportService.instance.exportToCsv(
        headers: headers,
        rows: rows,
        fileName:
            'inventory_low_stock_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Low stock items exported successfully!'),
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

  List<InventoryItem> _getFilteredItems(String category) {
    // Match category case-insensitively and ignore surrounding whitespace so
    // 'Spare Parts', 'spare parts', or 'Spare parts' are treated the same.
    final catNorm = category.toLowerCase().trim();
    var filtered =
        _allItems
            .where((item) => item.category.toLowerCase().trim() == catNorm)
            .toList();

    // Filter by status
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'All') {
      filtered =
          filtered.where((item) => item.type == _selectedStatusFilter).toList();
    }

    return filtered;
  }

  Color _getStatusColor(String type) {
    switch (type.toLowerCase()) {
      case 'fresh':
        return Colors.green;
      case 'recycled':
        return Colors.blue;
      case 'returned':
        return Colors.purple;
      case 'used':
        return Colors.brown;
      case 'spare':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
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
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Inventory',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Manage stock & items',
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
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Transaction History',
            onPressed: _showTransactionHistoryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Export',
            onPressed: _showExportOptionsDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Controls row - Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _loadInventory,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Spacer(),
                  if (_loading) const CircularProgressIndicator(),
                ],
              ),
            ),
            // Status filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatusFilter,
                decoration: InputDecoration(
                  labelText: 'Filter by Status',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items:
                    _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_capitalize(status)),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatusFilter = value;
                  });
                },
              ),
            ),
            // Category tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: _blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _blue,
                tabs:
                    _categories.map((category) {
                      return Tab(text: category);
                    }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Data table
            Expanded(
              child:
                  _loading && _allItems.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error Loading Inventory',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(color: Colors.red[600]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadInventory,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : _allItems.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Inventory Items',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first inventory item to get started',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditDialog(null),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : TabBarView(
                        controller: _tabController,
                        children:
                            _categories.map((category) {
                              return _buildCategoryTable(category);
                            }).toList(),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _allowedStatusesForCategory(String category) {
    final cat = category.toLowerCase().trim();
    switch (cat) {
      case 'raw materials':
        return ['recycled', 'fresh'];
      case 'finished goods':
        return ['fresh', 'returned'];
      case 'additives':
        // Additives can only be fresh
        return ['fresh'];
      case 'spare parts':
        return ['fresh', 'used'];
      default:
        return _statusOptions.skip(1).toList();
    }
  }

  Widget _buildCategoryTable(String category) {
    final filteredItems = _getFilteredItems(category);

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No items in $category'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: _buildDataTable(filteredItems, category),
      ),
    );
  }

  Widget _buildDataTable(List<InventoryItem> items, String category) {
    // Check if this category should show +/- buttons
    final showQuantityButtons =
        category.toLowerCase().trim() == 'spare parts' ||
        category.toLowerCase().trim() == 'additives';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
        border: TableBorder.all(color: Colors.grey.shade300),
        columns: const [
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Material',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Required',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Min Qty',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows:
            items.map((item) {
              final statusColor = _getStatusColor(item.type);
              final total = _getTotal(item);
              final required = _getRequired(item);
              final stock = total - required;
              final minQty = _getMinQty(item);

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        item.type.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(item.name)), // Material
                  DataCell(Text(total.toString())), // Total
                  DataCell(Text(required.toString())), // Required
                  DataCell(Text(stock.toString())), // Stock (calculated)
                  DataCell(Text(minQty.toString())), // Min Qty
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show +/- buttons for Spare Parts and Additives
                        if (showQuantityButtons) ...[
                          IconButton(
                            icon: const Icon(Icons.add_circle, size: 18),
                            onPressed: () => _showAddQuantityDialog(item),
                            tooltip: 'Add Quantity',
                            color: Colors.green,
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, size: 18),
                            onPressed: () => _showConsumeQuantityDialog(item),
                            tooltip: 'Consume Quantity',
                            color: Colors.orange,
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showAddEditDialog(item),
                          tooltip: 'Edit',
                          color: Colors.blue,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => _deleteItem(item),
                          tooltip: 'Delete',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  /// Show dialog to add quantity to an item (for Spare Parts and Additives)
  void _showAddQuantityDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  titlePadding: EdgeInsets.zero,
                  title: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Add Quantity',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Item: ${item.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current Quantity: ${item.quantity.toInt()}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Quantity to Add *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.add, color: Colors.green),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Date Picker
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Addition Date *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: Colors.green,
                              ),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final addQty =
                            double.tryParse(quantityController.text) ?? 0;
                        if (addQty <= 0) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid quantity greater than 0',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        final inventoryService = InventoryService();
                        final success = await inventoryService
                            .addQuantityWithHistory(
                              item: item,
                              quantity: addQty,
                              additionDate: selectedDate,
                            );

                        if (success) {
                          await _loadInventory();
                          if (mounted) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added ${addQty.toInt()} to ${item.name}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  inventoryService.lastError ??
                                      'Failed to add quantity',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
          ),
    );
  }

  /// Show dialog to consume/remove quantity from an item (for Spare Parts and Additives)
  void _showConsumeQuantityDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  titlePadding: EdgeInsets.zero,
                  title: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade700,
                          Colors.orange.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Consume Quantity',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Item: ${item.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current Quantity: ${item.quantity.toInt()}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Quantity to Consume *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.remove,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Date Picker
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Consumption Date *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: Colors.orange,
                              ),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final consumeQty =
                            double.tryParse(quantityController.text) ?? 0;
                        if (consumeQty <= 0) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid quantity greater than 0',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        if (consumeQty > item.quantity) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Cannot consume more than available (${item.quantity.toInt()})',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final inventoryService = InventoryService();
                        final success = await inventoryService
                            .consumeQuantityWithHistory(
                              item: item,
                              quantity: consumeQty,
                              consumptionDate: selectedDate,
                            );

                        if (success) {
                          await _loadInventory();
                          if (mounted) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Consumed ${consumeQty.toInt()} from ${item.name}',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  inventoryService.lastError ??
                                      'Failed to consume quantity',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Consume'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showAddEditDialog(InventoryItem? item) {
    final isEdit = item != null;
    final materialController = TextEditingController(text: item?.name ?? '');
    final totalController = TextEditingController(
      text: item != null ? _getTotal(item).toString() : '0',
    );
    final minQtyController = TextEditingController(
      text: item != null ? _getMinQty(item).toString() : '0',
    );

    // Prepare category and type options constrained by the category.
    final categoryOptions = [
      'Raw Materials',
      'Finished Goods',
      'Additives',
      'Spare Parts',
    ];

    String selectedCategory = item?.category ?? categoryOptions[0];
    // Start with the allowed statuses for the initial category
    List<String> allowedTypes = _allowedStatusesForCategory(selectedCategory);

    // If the existing item has a type that's allowed for the category, keep it,
    // otherwise default to the first allowed type.
    String selectedType =
        (item?.type != null && allowedTypes.contains(item!.type))
            ? item.type
            : (allowedTypes.isNotEmpty ? allowedTypes.first : 'fresh');

    // Capture the parent context so we don't use a possibly deactivated
    // dialog context after awaiting async operations.
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setState) => AlertDialog(
                  // Custom styled title with admin gradient
                  titlePadding: EdgeInsets.zero,
                  title: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Item' : 'Add New Item',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  content: Builder(
                    builder: (innerCtx) {
                      // Use MediaQuery from the inner context to react to viewInsets
                      final bottomInset =
                          MediaQuery.of(innerCtx).viewInsets.bottom;
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: bottomInset),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Category FIRST
                            DropdownButtonFormField<String>(
                              initialValue: selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category (Editable)',
                                border: OutlineInputBorder(),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              items:
                                  categoryOptions.map((cat) {
                                    return DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedCategory = value;
                                    // recompute allowed types and ensure selectedType is valid
                                    allowedTypes = _allowedStatusesForCategory(
                                      selectedCategory,
                                    );
                                    if (!allowedTypes.contains(selectedType)) {
                                      selectedType =
                                          allowedTypes.isNotEmpty
                                              ? allowedTypes.first
                                              : 'fresh';
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            // Type SECOND
                            DropdownButtonFormField<String>(
                              initialValue: selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Type (Editable)',
                                border: OutlineInputBorder(),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              items:
                                  allowedTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(_capitalize(type)),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedType = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            // Material THIRD
                            TextField(
                              controller: materialController,
                              decoration: const InputDecoration(
                                labelText: 'Material (Editable)',
                                border: OutlineInputBorder(),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              enabled: true,
                            ),
                            const SizedBox(height: 12),
                            // Total FOURTH
                            TextField(
                              controller: totalController,
                              decoration: const InputDecoration(
                                labelText: 'Total (Editable)',
                                border: OutlineInputBorder(),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            // Min Qty FIFTH
                            TextField(
                              controller: minQtyController,
                              decoration: const InputDecoration(
                                labelText: 'Min Quantity (Editable)',
                                border: OutlineInputBorder(),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Note: Required is default 0\nStock = Total - Required',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(parentContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final materialName = materialController.text.trim();

                        if (materialName.isEmpty) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Material name cannot be empty'),
                            ),
                          );
                          return;
                        }

                        // Ensure chosen type is allowed for selected category
                        final allowed = _allowedStatusesForCategory(
                          selectedCategory,
                        );
                        if (!allowed.contains(selectedType)) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                '"${_capitalize(selectedType)}" is not allowed for category "$selectedCategory".',
                              ),
                            ),
                          );
                          return;
                        }

                        if (isEdit) {
                          // Update existing item
                          final updated = InventoryItem(
                            id: item.id,
                            name: materialName,
                            type: selectedType,
                            quantity:
                                double.tryParse(totalController.text) ?? 0.0,
                            minQuantity:
                                minQtyController.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(minQtyController.text),
                            category: selectedCategory,
                          );
                          await _updateItem(updated);
                        } else {
                          // Add new item
                          final newItem = InventoryItem(
                            name: materialName,
                            type: selectedType,
                            quantity:
                                double.tryParse(totalController.text) ?? 0.0,
                            minQuantity:
                                minQtyController.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(minQtyController.text),
                            category: selectedCategory,
                          );
                          await _addItem(newItem);
                        }

                        if (mounted) {
                          try {
                            if (Navigator.of(parentContext).canPop()) {
                              Navigator.of(parentContext).pop();
                            }
                          } catch (_) {
                            // ignore - safe fallback
                          }
                        }
                      },
                      child: Text(isEdit ? 'Update' : 'Add'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _addItem(InventoryItem item) async {
    try {
      final service = SupabaseService();
      if (service.isAuthenticated) {
        await service.addInventoryItem(item);
        await _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item added successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
      }
    }
  }

  Future<void> _updateItem(InventoryItem item) async {
    try {
      final service = SupabaseService();
      if (service.isAuthenticated) {
        await service.updateInventoryItem(item);
        await _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update item: $e')));
      }
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Are you sure you want to delete "${item.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true && item.id != null) {
      try {
        final service = SupabaseService();
        if (service.isAuthenticated) {
          await service.deleteInventoryItem(item.id!);
          await _loadInventory();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Item deleted successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
        }
      }
    }
  }
}

/// Dialog widget to display transaction history (additions and consumptions)
class _TransactionHistoryDialog extends StatefulWidget {
  @override
  State<_TransactionHistoryDialog> createState() =>
      _TransactionHistoryDialogState();
}

class _TransactionHistoryDialogState extends State<_TransactionHistoryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<InventoryAddition> _additions = [];
  List<InventoryConsumption> _consumptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final service = InventoryService();
    final additions = await service.fetchAdditions();
    final consumptions = await service.fetchConsumptions();
    if (mounted) {
      setState(() {
        _additions = additions;
        _consumptions = consumptions;
        _loading = false;
      });
    }
  }

  void _showDownloadOptions() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.download, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Text('Download History'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_circle, color: Colors.green.shade600),
                  title: const Text('Download Additions'),
                  subtitle: Text('${_additions.length} records'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportAdditions();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.remove_circle,
                    color: Colors.orange.shade600,
                  ),
                  title: const Text('Download Consumptions'),
                  subtitle: Text('${_consumptions.length} records'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportConsumptions();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _exportAdditions() async {
    if (_additions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No addition records to export!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final headers = ['Date', 'Item Name', 'Quantity'];
    final rows =
        _additions.map((a) {
          return [
            DateFormat('dd/MM/yyyy').format(a.additionDate),
            a.itemName,
            a.quantity.toStringAsFixed(0),
          ];
        }).toList();

    await ExcelExportService.instance.exportToCsv(
      headers: headers,
      rows: rows,
      fileName:
          'inventory_additions_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Additions exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _exportConsumptions() async {
    if (_consumptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No consumption records to export!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final headers = ['Date', 'Item Name', 'Quantity'];
    final rows =
        _consumptions.map((c) {
          return [
            DateFormat('dd/MM/yyyy').format(c.consumptionDate),
            c.itemName,
            c.quantity.toStringAsFixed(0),
          ];
        }).toList();

    await ExcelExportService.instance.exportToCsv(
      headers: headers,
      rows: rows,
      fileName:
          'inventory_consumptions_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consumptions exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Transaction History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadData,
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: _showDownloadOptions,
                    tooltip: 'Download',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tab Bar
            Container(
              color: Colors.grey.shade100,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue.shade700,
                tabs: [
                  Tab(
                    icon: Icon(Icons.add_circle, color: Colors.green.shade600),
                    text: 'Additions (${_additions.length})',
                  ),
                  Tab(
                    icon: Icon(
                      Icons.remove_circle,
                      color: Colors.orange.shade600,
                    ),
                    text: 'Consumptions (${_consumptions.length})',
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAdditionsTable(),
                          _buildConsumptionsTable(),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionsTable() {
    if (_additions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No addition records found',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
            border: TableBorder.all(color: Colors.grey.shade300),
            columns: const [
              DataColumn(
                label: Text(
                  'Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Item',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Qty',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows:
                _additions.map((a) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(DateFormat('dd/MM/yyyy').format(a.additionDate)),
                      ),
                      DataCell(Text(a.itemName)),
                      DataCell(Text(a.quantity.toStringAsFixed(0))),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildConsumptionsTable() {
    if (_consumptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.remove_circle_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No consumption records found',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.orange.shade50),
            border: TableBorder.all(color: Colors.grey.shade300),
            columns: const [
              DataColumn(
                label: Text(
                  'Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Item',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Qty',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows:
                _consumptions.map((c) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat('dd/MM/yyyy').format(c.consumptionDate),
                        ),
                      ),
                      DataCell(Text(c.itemName)),
                      DataCell(Text(c.quantity.toStringAsFixed(0))),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}
