import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inventory',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
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
                  const Spacer(),
                  if (_loading) const CircularProgressIndicator(),
                ],
              ),
            ),
            // Status filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String>(
                value: _selectedStatusFilter,
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
        // allow all known statuses (except 'All' placeholder)
        return _statusOptions.skip(1).toList();
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
      child: SingleChildScrollView(child: _buildDataTable(filteredItems)),
    );
  }

  Widget _buildDataTable(List<InventoryItem> items) {
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
                            DropdownButtonFormField<String>(
                              value: selectedType,
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
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
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
