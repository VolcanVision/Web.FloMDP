import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/wire_card.dart';
import '../models/production_batch.dart';
import '../widgets/back_to_dashboard.dart';
import '../services/supabase_service.dart';
import '../models/inventory_item.dart';

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key});

  @override
  _ProductionPageState createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  List<ProductionQueue> productionBatches = [];
  List<ProductionQueueItem> queueItems = [];
  bool _loading = false;

  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProductionBatches();
  }

  Future<void> _loadProductionBatches() async {
    setState(() => _loading = true);
    try {
      final service = SupabaseService();
      if (!service.isAuthenticated) {
        await service.signInAnonymously();
      }

      final batches = await service.getProductionBatches();

      productionBatches = [];
      queueItems = [];

      int position = 1;
      for (var batch in batches) {
        // Map existing schema to our model
        final batchNo = batch['batch_no'] ?? 'BATCH-${batch['id']}';
        final details = batch['details'] ?? '';
        final inventoryId = 'inv_${batch['id']}';

        // Parse product name and quantity from details if formatted as "ProductName (Qty: X)"
        String productName = details;
        int quantity = 0;
        final qtyMatch = RegExp(r'\(Qty:\s*(\d+)\)').firstMatch(details);
        if (qtyMatch != null) {
          quantity = int.tryParse(qtyMatch.group(1) ?? '0') ?? 0;
          productName = details.replaceAll(qtyMatch.group(0) ?? '', '').trim();
        }

        // Map database status to our app status
        String appStatus = 'queued';
        // Load progress from database, default to 0.0 if not present
        double progress = (batch['progress'] as num?)?.toDouble() ?? 0.0;

        if (batch['status'] == 'in_production') {
          appStatus = 'in_progress';
          // Keep the progress value from database
        } else if (batch['status'] == 'ready') {
          appStatus = 'completed';
          progress = 100.0; // Completed items are always 100%
        } else if (batch['status'] == 'paused') {
          appStatus = 'paused';
          // Keep the progress value from database
        }

        final completed = batch['status'] == 'ready';

        productionBatches.add(
          ProductionQueue(
            id: batch['id'].toString(),
            batchNumber: batchNo,
            inventoryId: inventoryId,
            status: appStatus,
            progress: progress,
            createdAt:
                batch['created_at'] != null
                    ? DateTime.parse(batch['created_at'])
                    : DateTime.now(),
            updatedAt:
                batch['started_at'] != null
                    ? DateTime.parse(batch['started_at'])
                    : DateTime.now(),
          ),
        );

        queueItems.add(
          ProductionQueueItem(
            id: batch['id'].toString(),
            inventoryId: inventoryId,
            productName: productName,
            quantity: quantity,
            completed: completed,
            queuePosition: completed ? 0 : position++,
            createdAt:
                batch['created_at'] != null
                    ? DateTime.parse(batch['created_at'])
                    : DateTime.now(),
            updatedAt:
                batch['started_at'] != null
                    ? DateTime.parse(batch['started_at'])
                    : DateTime.now(),
          ),
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading production batches: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateBatchStatus(
    String batchId,
    String newStatus, {
    double? progress,
  }) async {
    int index = productionBatches.indexWhere((batch) => batch.id == batchId);
    if (index == -1) return;

    ProductionQueue batch = productionBatches[index];

    // Manage queue positions when status changes
    if (newStatus == 'completed') {
      // When completing a batch, remove it from active queue positions
      _removeFromActiveQueueAndShift(batch.inventoryId);
    } else if (newStatus == 'paused') {
      // When pausing a batch, move it to the end of the active queue
      _moveQueueItemToEnd(batch.inventoryId);
    } else if (newStatus == 'in_progress') {
      // When starting a batch, place it after already started processes and before paused ones
      final placePos = _lastInProgressPosition() + 1;
      _insertQueueItemAtPosition(batch.inventoryId, placePos);
    } else if (batch.status == 'completed' && newStatus != 'completed') {
      // Resurrecting a completed batch -> put at end of queue
      _addToEndQueue(batch.inventoryId);
    } else if (batch.status == 'paused' && newStatus == 'in_progress') {
      // When resuming a paused batch, move it to the end of the queue
      _moveQueueItemToEnd(batch.inventoryId);
    }

    final finalProgress =
        progress ??
        (newStatus == 'completed'
            ? 100.0
            : newStatus == 'in_progress'
            ? 0.0
            : batch.progress);

    // Update in database
    final service = SupabaseService();
    await service.updateProductionBatchStatus(
      batchId,
      newStatus,
      progress: finalProgress,
    );

    // Update local state
    setState(() {
      productionBatches[index] = ProductionQueue(
        id: batch.id,
        batchNumber: batch.batchNumber,
        inventoryId: batch.inventoryId,
        status: newStatus,
        progress: finalProgress,
        createdAt: batch.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  // Helper: returns the max queuePosition for non-completed items
  int _maxActiveQueuePosition() {
    final positions = queueItems
        .where((i) => !i.completed && i.queuePosition > 0)
        .map((i) => i.queuePosition);
    return positions.isEmpty ? 0 : positions.reduce((a, b) => a > b ? a : b);
  }

  String _formatBatchNumber(int n) => 'BATCH-${n.toString().padLeft(3, '0')}';

  int _nextBatchIndex() {
    final regex = RegExp(r'(\d+)');
    int max = 0;
    for (final b in productionBatches) {
      final m = regex.firstMatch(b.batchNumber);
      if (m != null) {
        final val = int.tryParse(m.group(1) ?? '0') ?? 0;
        if (val > max) max = val;
      }
    }
    return max + 1;
  }

  // Compute the display batch number (BATCH-###) based on the current queue position.
  // If the item is in the active queue (queuePosition > 0) we map that position to the batch number.
  // Otherwise we fall back to the stored batchNumber.
  String _displayBatchNumberFor(ProductionQueue batch) {
    final qi = queueItems.firstWhere(
      (item) => item.inventoryId == batch.inventoryId,
      orElse:
          () => ProductionQueueItem(
            id: 'unknown',
            inventoryId: batch.inventoryId,
            productName: 'Unknown',
            quantity: 0,
            queuePosition: 0,
          ),
    );

    if (qi.queuePosition > 0) {
      return _formatBatchNumber(qi.queuePosition);
    }

    return batch.batchNumber;
  }

  // Remove queue item from active queue and shift down higher positions
  void _removeFromActiveQueueAndShift(String inventoryId) {
    final idx = queueItems.indexWhere((i) => i.inventoryId == inventoryId);
    if (idx == -1) return;
    final oldPos = queueItems[idx].queuePosition;

    // Mark item as completed by setting queuePosition to 0 (or keep but mark completed flag)
    queueItems[idx] = ProductionQueueItem(
      id: queueItems[idx].id,
      inventoryId: queueItems[idx].inventoryId,
      productName: queueItems[idx].productName,
      quantity: queueItems[idx].quantity,
      completed: true,
      queuePosition: 0,
    );

    // Shift down any items that had a greater position
    for (int i = 0; i < queueItems.length; i++) {
      if (!queueItems[i].completed && queueItems[i].queuePosition > oldPos) {
        queueItems[i] = ProductionQueueItem(
          id: queueItems[i].id,
          inventoryId: queueItems[i].inventoryId,
          productName: queueItems[i].productName,
          quantity: queueItems[i].quantity,
          completed: queueItems[i].completed,
          queuePosition: queueItems[i].queuePosition - 1,
        );
      }
    }
  }

  // Add an existing queue item (by inventoryId) to the end of active queue
  void _addToEndQueue(String inventoryId) {
    final idx = queueItems.indexWhere((i) => i.inventoryId == inventoryId);
    final nextPos = _maxActiveQueuePosition() + 1;
    if (idx == -1) return;
    queueItems[idx] = ProductionQueueItem(
      id: queueItems[idx].id,
      inventoryId: queueItems[idx].inventoryId,
      productName: queueItems[idx].productName,
      quantity: queueItems[idx].quantity,
      completed: false,
      queuePosition: nextPos,
    );
  }

  // Move an active queue item to the end (used for resume behavior)
  void _moveQueueItemToEnd(String inventoryId) {
    final idx = queueItems.indexWhere((i) => i.inventoryId == inventoryId);
    if (idx == -1) return;
    final oldPos = queueItems[idx].queuePosition;
    final nextPos = _maxActiveQueuePosition();
    if (oldPos == 0) {
      // If it wasn't in queue, just add to end
      _addToEndQueue(inventoryId);
      return;
    }

    // Shift down any items that had a greater position
    for (int i = 0; i < queueItems.length; i++) {
      if (!queueItems[i].completed && queueItems[i].queuePosition > oldPos) {
        queueItems[i] = ProductionQueueItem(
          id: queueItems[i].id,
          inventoryId: queueItems[i].inventoryId,
          productName: queueItems[i].productName,
          quantity: queueItems[i].quantity,
          completed: queueItems[i].completed,
          queuePosition: queueItems[i].queuePosition - 1,
        );
      }
    }

    // Put this item at the end (old max becomes new max)
    queueItems[idx] = ProductionQueueItem(
      id: queueItems[idx].id,
      inventoryId: queueItems[idx].inventoryId,
      productName: queueItems[idx].productName,
      quantity: queueItems[idx].quantity,
      completed: false,
      queuePosition: nextPos,
    );
  }

  // Insert or move a queue item to a specific target position (1-based).
  // This will shift other active items up or down to preserve unique positions.
  void _insertQueueItemAtPosition(String inventoryId, int targetPos) {
    if (targetPos < 1) targetPos = 1;

    final idx = queueItems.indexWhere((i) => i.inventoryId == inventoryId);
    if (idx == -1) return;

    final oldPos = queueItems[idx].queuePosition;

    // If item was not in active queue (oldPos == 0), we need to shift items at >= targetPos up by 1
    if (oldPos == 0) {
      for (int i = 0; i < queueItems.length; i++) {
        if (!queueItems[i].completed &&
            queueItems[i].queuePosition >= targetPos) {
          queueItems[i] = ProductionQueueItem(
            id: queueItems[i].id,
            inventoryId: queueItems[i].inventoryId,
            productName: queueItems[i].productName,
            quantity: queueItems[i].quantity,
            completed: queueItems[i].completed,
            queuePosition: queueItems[i].queuePosition + 1,
          );
        }
      }
      queueItems[idx] = ProductionQueueItem(
        id: queueItems[idx].id,
        inventoryId: queueItems[idx].inventoryId,
        productName: queueItems[idx].productName,
        quantity: queueItems[idx].quantity,
        completed: false,
        queuePosition: targetPos,
      );
      return;
    }

    if (oldPos == targetPos) return;

    if (oldPos < targetPos) {
      // Moving down: decrement positions of items between oldPos+1 .. targetPos
      for (int i = 0; i < queueItems.length; i++) {
        if (!queueItems[i].completed &&
            queueItems[i].queuePosition > oldPos &&
            queueItems[i].queuePosition <= targetPos) {
          queueItems[i] = ProductionQueueItem(
            id: queueItems[i].id,
            inventoryId: queueItems[i].inventoryId,
            productName: queueItems[i].productName,
            quantity: queueItems[i].quantity,
            completed: queueItems[i].completed,
            queuePosition: queueItems[i].queuePosition - 1,
          );
        }
      }
      queueItems[idx] = ProductionQueueItem(
        id: queueItems[idx].id,
        inventoryId: queueItems[idx].inventoryId,
        productName: queueItems[idx].productName,
        quantity: queueItems[idx].quantity,
        completed: false,
        queuePosition: targetPos,
      );
      return;
    }

    // oldPos > targetPos : moving up
    for (int i = 0; i < queueItems.length; i++) {
      if (!queueItems[i].completed &&
          queueItems[i].queuePosition >= targetPos &&
          queueItems[i].queuePosition < oldPos) {
        queueItems[i] = ProductionQueueItem(
          id: queueItems[i].id,
          inventoryId: queueItems[i].inventoryId,
          productName: queueItems[i].productName,
          quantity: queueItems[i].quantity,
          completed: queueItems[i].completed,
          queuePosition: queueItems[i].queuePosition + 1,
        );
      }
    }
    queueItems[idx] = ProductionQueueItem(
      id: queueItems[idx].id,
      inventoryId: queueItems[idx].inventoryId,
      productName: queueItems[idx].productName,
      quantity: queueItems[idx].quantity,
      completed: false,
      queuePosition: targetPos,
    );
  }

  // Place the given inventoryId after all currently in-progress items (i.e., behind started processes)
  int _lastInProgressPosition() {
    int max = 0;
    for (final b in productionBatches) {
      if (b.status == 'in_progress') {
        final qi = queueItems.firstWhere(
          (item) => item.inventoryId == b.inventoryId,
          orElse:
              () => ProductionQueueItem(
                id: 'unknown',
                inventoryId: b.inventoryId,
                productName: 'Unknown',
                quantity: 0,
                queuePosition: 0,
              ),
        );
        if (qi.queuePosition > max) max = qi.queuePosition;
      }
    }
    return max;
  }

  Future<void> _addBatch(String productName, int quantity) async {
    final nextIndex = _nextBatchIndex();
    final batchNumber = _formatBatchNumber(nextIndex);
    final newInventoryId = 'inv_${DateTime.now().millisecondsSinceEpoch}';
    final queuePosition = _maxActiveQueuePosition() + 1;

    // Add to database using existing schema (batch_no, details for product_name)
    final service = SupabaseService();
    final batchData = {
      'batch_no': batchNumber,
      'details': '$productName (Qty: $quantity)',
      'status': 'in_production', // Use existing status values
      'order_id': null, // Not linked to specific order in queue mode
    };

    final result = await service.addProductionBatch(batchData);

    if (result != null) {
      // Add to local state immediately
      final newBatch = ProductionQueue(
        id: result['id'].toString(),
        batchNumber: batchNumber,
        inventoryId: newInventoryId,
        status: 'in_progress',
        progress: 0.0,
      );

      final newQueueItem = ProductionQueueItem(
        id: result['id'].toString(),
        inventoryId: newInventoryId,
        productName: productName,
        quantity: quantity,
        queuePosition: queuePosition,
      );

      setState(() {
        productionBatches.add(newBatch);
        queueItems.add(newQueueItem);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Batch $batchNumber added successfully'),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add batch. Please try again.'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _showAddBatchDialog() {
    _productNameController.clear();
    _quantityController.clear();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Container(
              padding: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Text(
                'Add New Production Batch',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Batch number is autogenerated; user does not input it
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _productNameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(
                          Icons.inventory,
                          color: Colors.green[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(
                          Icons.numbers,
                          color: Colors.orange[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_productNameController.text.isNotEmpty &&
                      _quantityController.text.isNotEmpty) {
                    _addBatch(
                      _productNameController.text,
                      int.tryParse(_quantityController.text) ?? 0,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text('Add Batch'),
              ),
            ],
          ),
    );
  }

  void _showPauseDialog(ProductionQueue batch, ProductionQueueItem queueItem) {
    final TextEditingController unitsController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Pause Production'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Batch: ${batch.batchNumber}'),
                Text('Product: ${queueItem.productName}'),
                Text('Total Quantity: ${queueItem.quantity} units'),
                SizedBox(height: 16),
                TextField(
                  controller: unitsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Total units processed so far',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 50',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final processed =
                      double.tryParse(unitsController.text) ?? 0.0;
                  final total = queueItem.quantity.toDouble();

                  if (total > 0) {
                    // Calculate progress based on units entered
                    final calculatedProgress = (processed / total * 100).clamp(
                      0.0,
                      100.0,
                    );

                    _updateBatchStatus(
                      batch.id,
                      'paused',
                      progress: calculatedProgress,
                    );
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Production paused at ${calculatedProgress.toInt()}% (${processed.toInt()} units)',
                        ),
                        backgroundColor: Colors.orange[700],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
                child: Text('Confirm Pause'),
              ),
            ],
          ),
    );
  }

  void _showMoveToInventoryDialog(
    ProductionQueue batch,
    ProductionQueueItem queueItem,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Container(
              padding: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Text(
                'Move to Inventory',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product: ${queueItem.productName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Quantity: ${queueItem.quantity} units',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This will add the item to "Finished Goods" in Inventory',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _moveToInventory(batch, queueItem);
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text('Move to Inventory'),
              ),
            ],
          ),
    );
  }

  Future<void> _moveToInventory(
    ProductionQueue batch,
    ProductionQueueItem queueItem,
  ) async {
    try {
      // Import SupabaseService and InventoryItem
      final service = SupabaseService();

      // Normalize the product name: lowercase and trim whitespace
      final normalizedName = queueItem.productName.toLowerCase().trim();

      // Check if item with same normalized name already exists in "Finished Goods"
      final existingItems = await service.getInventoryItems();
      final existingItem = existingItems.cast<InventoryItem?>().firstWhere(
        (item) =>
            item != null &&
            item.name.toLowerCase().trim() == normalizedName &&
            item.category == 'Finished Goods',
        orElse: () => null,
      );

      bool success = false;

      if (existingItem != null) {
        // Item exists - update quantity
        final updatedItem = InventoryItem(
          id: existingItem.id,
          name: existingItem.name,
          type: existingItem.type,
          quantity: existingItem.quantity + queueItem.quantity.toDouble(),
          category: existingItem.category,
          minQuantity: existingItem.minQuantity,
        );

        success = await service.updateInventoryItem(updatedItem);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✓ Added ${queueItem.quantity} units to existing "${existingItem.name}" in Inventory',
              ),
              backgroundColor: Colors.green[600],
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Item does not exist - create new inventory item
        final inventoryItem = InventoryItem(
          name:
              queueItem.productName
                  .trim(), // Keep original case for display, just trim
          type: 'fresh', // Default status
          quantity: queueItem.quantity.toDouble(),
          category: 'Finished Goods',
        );

        final result = await service.addInventoryItem(inventoryItem);
        success = result != null;

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✓ Successfully added to Inventory - Finished Goods',
              ),
              backgroundColor: Colors.green[600],
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      if (success) {
        // 1. Mark batch as moved to inventory (keep in production_batches for history)
        await service.updateProductionBatch(batch.id, {
          'moved_to_inventory': true,
        });

        // 2. Delete from production_queue table (removes from queue display)
        await service.deleteProductionQueueItem(queueItem.id);

        // 3. Remove from local state
        setState(() {
          productionBatches.removeWhere((b) => b.id == batch.id);
          queueItems.removeWhere((qi) => qi.inventoryId == batch.inventoryId);
        });
      } else {
        // Failed to add/update inventory
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update inventory. Please try again.'),
              backgroundColor: Colors.red[600],
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error moving to inventory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[600],
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildDraggableBatchCard(
    ProductionQueue batch,
    ProductionQueueItem queueItem, {
    required Key key,
  }) {
    // Compact card: smaller paddings, condensed info for phone screens.
    final statusColor = batch.statusColor;
    final statusIcon =
        batch.status == 'in_progress'
            ? Icons.play_arrow
            : batch.status == 'completed'
            ? Icons.check
            : batch.status == 'paused'
            ? Icons.pause
            : Icons.schedule;

    // Find the index of this item in the active queue for ReorderableDragStartListener
    final activeQueue =
        queueItems.where((qi) => !qi.completed && qi.queuePosition > 0).toList()
          ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
    final itemIndex = activeQueue.indexWhere((qi) => qi.id == queueItem.id);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showBatchDetails(batch, queueItem),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: statusColor, width: 4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Drag handle for web - placed on the far left
                if (kIsWeb && itemIndex >= 0)
                  ReorderableDragStartListener(
                    index: itemIndex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.drag_indicator,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(statusIcon, color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              queueItem.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[850],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Q#${queueItem.queuePosition}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${queueItem.quantity} units',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 6,
                                  child: LinearProgressIndicator(
                                    value:
                                        (batch.progress.clamp(0, 100)) / 100.0,
                                    color: statusColor,
                                    backgroundColor: Colors.grey[200],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${batch.progress.toInt()}% Completed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  itemBuilder:
                      (ctx) => <PopupMenuEntry<String>>[
                        if (batch.status != 'completed')
                          const PopupMenuItem(
                            value: 'start',
                            child: Text('Start'),
                          ),
                        if (batch.status != 'paused')
                          const PopupMenuItem(
                            value: 'pause',
                            child: Text('Pause'),
                          ),
                        if (batch.status != 'completed')
                          const PopupMenuItem(
                            value: 'complete',
                            child: Text('Complete'),
                          ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Details'),
                        ),
                      ],
                  onSelected: (v) {
                    if (v == 'start') {
                      _updateBatchStatus(batch.id, 'in_progress');
                    }
                    if (v == 'pause') _showPauseDialog(batch, queueItem);
                    if (v == 'complete') {
                      _updateBatchStatus(batch.id, 'completed');
                    }
                    if (v == 'details') _showBatchDetails(batch, queueItem);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBatchDetails(ProductionQueue batch, ProductionQueueItem queueItem) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Batch Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Text('Product: ${queueItem.productName}'),
                Text('Quantity: ${queueItem.quantity}'),
                Text('Status: ${batch.status}'),
                Text('Progress: ${batch.progress.toInt()}%'),
                Text('Created: ${batch.createdAt.toString().split(' ')[0]}'),
                Text('Queue Position: ${queueItem.queuePosition}'),
              ],
            ),
            actions: [
              if (batch.status != 'completed') ...[
                TextButton(
                  onPressed: () {
                    _updateBatchStatus(batch.id, 'in_progress');
                    Navigator.pop(context);
                  },
                  child: Text('Start'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close details dialog
                    _showPauseDialog(batch, queueItem);
                  },
                  child: Text('Pause'),
                ),
                TextButton(
                  onPressed: () {
                    _updateBatchStatus(batch.id, 'completed');
                    Navigator.pop(context);
                  },
                  child: Text('Complete'),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No route args needed for back handling; BackToDashboardButton resolves home route

    return Scaffold(
      backgroundColor: Colors.white,
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
              'Production Queue',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage and reorder batches',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBatchDialog,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Add New Batch',
        child: Icon(Icons.add, size: 28),
      ),
      body:
          _loading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Production Queue List - Active and Completed sections
                    WireCard(
                      title: 'Production Queue',
                      titleColor: Colors.blue.shade700,
                      child: () {
                        // Build list of active batches ordered by queue position
                        final activeQueue =
                            queueItems
                                .where(
                                  (qi) => !qi.completed && qi.queuePosition > 0,
                                )
                                .toList()
                              ..sort(
                                (a, b) =>
                                    a.queuePosition.compareTo(b.queuePosition),
                              );

                        if (activeQueue.isEmpty) {
                          return SizedBox(
                            height: 160,
                            child: Center(
                              child: Text(
                                'No active batches in queue',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        // Use ReorderableListView for drag-and-drop
                        return ReorderableListView(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles:
                              !kIsWeb, // Use custom drag handles on web
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = activeQueue.removeAt(oldIndex);
                              activeQueue.insert(newIndex, item);

                              // Update queue positions
                              for (int i = 0; i < activeQueue.length; i++) {
                                final idx = queueItems.indexWhere(
                                  (qi) => qi.id == activeQueue[i].id,
                                );
                                if (idx != -1) {
                                  queueItems[idx] = ProductionQueueItem(
                                    id: queueItems[idx].id,
                                    inventoryId: queueItems[idx].inventoryId,
                                    productName: queueItems[idx].productName,
                                    quantity: queueItems[idx].quantity,
                                    completed: queueItems[idx].completed,
                                    queuePosition: i + 1,
                                    createdAt: queueItems[idx].createdAt,
                                    updatedAt: queueItems[idx].updatedAt,
                                  );
                                }
                              }
                            });
                          },
                          children:
                              activeQueue.map((qi) {
                                final batch = productionBatches.firstWhere(
                                  (b) => b.inventoryId == qi.inventoryId,
                                  orElse:
                                      () => ProductionQueue(
                                        id: qi.id,
                                        batchNumber: 'UNKNOWN',
                                        inventoryId: qi.inventoryId,
                                        status: 'queued',
                                      ),
                                );
                                return _buildDraggableBatchCard(
                                  batch,
                                  qi,
                                  key: ValueKey(qi.id),
                                );
                              }).toList(),
                        );
                      }(),
                    ),

                    SizedBox(height: 16),

                    WireCard(
                      title: 'Completed Batches',
                      titleColor: Colors.blue.shade700,
                      child: () {
                        final completedBatches =
                            productionBatches
                                .where((b) => b.status == 'completed')
                                .toList();

                        if (completedBatches.isEmpty) {
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: Text(
                                'No completed batches',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children:
                              completedBatches.map((batch) {
                                final qi = queueItems.firstWhere(
                                  (item) =>
                                      item.inventoryId == batch.inventoryId,
                                  orElse:
                                      () => ProductionQueueItem(
                                        id: 'unknown',
                                        inventoryId: batch.inventoryId,
                                        productName: 'Unknown Product',
                                        quantity: 0,
                                        completed: true,
                                        queuePosition: 0,
                                      ),
                                );

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 12,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.green.withOpacity(
                                      0.12,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                  ),
                                  title: Text(
                                    qi.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Qty: ${qi.quantity}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.inventory_2),
                                        tooltip: 'Move to Inventory',
                                        onPressed:
                                            () => _showMoveToInventoryDialog(
                                              batch,
                                              qi,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.undo,
                                          color: Colors.orange,
                                        ),
                                        tooltip: 'Move back to queue',
                                        onPressed:
                                            () => _updateBatchStatus(
                                              batch.id,
                                              'queued',
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        );
                      }(),
                    ),
                  ],
                ),
              ),
    );
  }
}
