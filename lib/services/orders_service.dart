import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/customer.dart';
import 'supabase_service.dart';

class OrdersService {
  // Add an order item to the order_items table
  Future<void> addOrderItem(OrderItem item) async {
    await _supabaseService.addOrderItem(item);
    // Optionally, update local cache if you maintain one
  }

  // Update an existing order item
  Future<bool> updateOrderItem(OrderItem item) async {
    try {
      final ok = await _supabaseService.updateOrderItem(item);
      return ok;
    } catch (e) {
      debugPrint('Error updating order item: $e');
      return false;
    }
  }

  // Delete an order item
  Future<bool> deleteOrderItem(int itemId) async {
    try {
      final ok = await _supabaseService.deleteOrderItem(itemId);
      return ok;
    } catch (e) {
      debugPrint('Error deleting order item: $e');
      return false;
    }
  }

  // Get all order items for a given order
  Future<List<OrderItem>> getOrderItemsForOrder(int orderId) async {
    return await _supabaseService.getOrderItemsForOrder(orderId);
  }

  OrdersService._privateConstructor();
  static final OrdersService instance = OrdersService._privateConstructor();

  final SupabaseService _supabaseService = SupabaseService();

  // In-memory fallback for web when Supabase isn't available
  final List<Order> _ordersCache = [];
  final List<Customer> _customersCache = [];

  // Always prefer Supabase, use in-memory cache as fallback on web
  bool get useSupabase => !kIsWeb || _supabaseService.isAuthenticated;

  // Get all orders
  Future<List<Order>> getOrders() async {
    try {
      // Try Supabase first
      return await _supabaseService.getOrders();
    } catch (e) {
      debugPrint('Error getting orders from Supabase: $e');
      // Return cached orders for web or empty list
      return _ordersCache;
    }
  }

  // Get orders with customer information
  Future<List<Map<String, dynamic>>> getOrdersWithCustomers() async {
    try {
      // Try Supabase first
      final orders = await _supabaseService.getOrders();
      return orders.map((order) => order.toMap()).toList();
    } catch (e) {
      debugPrint('Error getting orders with customers from Supabase: $e');
      // Return cached orders
      return _ordersCache.map((order) => order.toMap()).toList();
    }
  }

  // Add a new order
  /// Create an order and optionally add order items.
  ///
  /// `products` is a list of maps with keys: 'name' and 'quantity'. If provided,
  /// the service will insert each product into `order_items` after the order
  /// row is created.
  Future<Order?> addOrder(
    Order order, {
    List<Map<String, dynamic>>? products,
  }) async {
    try {
      // Create a new Order instance with timestamps and order number
      final now = DateTime.now();
      final orderNumber = order.orderNumber ?? await _generateOrderNumber();
      final newOrder = Order(
        id: order.id,
        orderNumber: orderNumber,
        customerId: order.customerId,
        clientName: order.clientName,
        advancePaid: order.advancePaid,
        dueDate: order.dueDate,
        dispatchDate: order.dispatchDate,
        isAdvancePaid: order.isAdvancePaid,
        advancePaymentDate: order.advancePaymentDate,
        afterDispatchDays: order.afterDispatchDays,
        finalDueDate: order.finalDueDate,
        finalPaymentDate: order.finalPaymentDate,
        orderStatus: order.orderStatus,
        paymentStatus: order.paymentStatus,
        productionStatus: order.productionStatus,
        createdBy: order.createdBy,
        createdAt: now,
        updatedAt: now,
        totalAmount: order.totalAmount,
      );

      // Try Supabase first
      final addedOrder = await _supabaseService.addOrder(newOrder);
      if (addedOrder != null) {
        // If products provided, insert them into order_items with the new order id
        if (products != null && products.isNotEmpty) {
          for (final p in products) {
            try {
              final item = OrderItem(
                orderId: addedOrder.id!,
                productName: p['name']?.toString() ?? '',
                quantity:
                    (p['quantity'] is num)
                        ? p['quantity']
                        : (int.tryParse(p['quantity']?.toString() ?? '0') ?? 0),
                note: p['note']?.toString(),
                createdAt: DateTime.now(),
              );
              await addOrderItem(item);
            } catch (e) {
              debugPrint(
                'Failed to add order item for order ${addedOrder.id}: $e',
              );
            }
          }
        }
        _ordersCache.add(addedOrder);
        return addedOrder;
      }
      return null;
    } catch (e) {
      debugPrint('Error adding order to Supabase: $e');
      // Add to cache for web
      final now = DateTime.now();
      final orderNumber = order.orderNumber ?? await _generateOrderNumber();
      final newOrder = Order(
        id: DateTime.now().millisecondsSinceEpoch,
        orderNumber: orderNumber,
        customerId: order.customerId,
        clientName: order.clientName,
        advancePaid: order.advancePaid,
        dueDate: order.dueDate,
        dispatchDate: order.dispatchDate,
        isAdvancePaid: order.isAdvancePaid,
        advancePaymentDate: order.advancePaymentDate,
        afterDispatchDays: order.afterDispatchDays,
        finalDueDate: order.finalDueDate,
        finalPaymentDate: order.finalPaymentDate,
        orderStatus: order.orderStatus,
        paymentStatus: order.paymentStatus,
        productionStatus: order.productionStatus,
        createdBy: order.createdBy,
        createdAt: now,
        updatedAt: now,
        totalAmount: order.totalAmount,
      );
      _ordersCache.add(newOrder);
      return newOrder;
    }
  }

  // Update an order
  Future<bool> updateOrder(Order order) async {
    try {
      final updatedOrder = Order(
        id: order.id,
        orderNumber: order.orderNumber,
        customerId: order.customerId,
        clientName: order.clientName,
        advancePaid: order.advancePaid,
        dueDate: order.dueDate,
        dispatchDate: order.dispatchDate,
        isAdvancePaid: order.isAdvancePaid,
        advancePaymentDate: order.advancePaymentDate,
        afterDispatchDays: order.afterDispatchDays,
        finalDueDate: order.finalDueDate,
        finalPaymentDate: order.finalPaymentDate,
        orderStatus: order.orderStatus,
        paymentStatus: order.paymentStatus,
        productionStatus: order.productionStatus,
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
        totalAmount: order.totalAmount,
      );

      // Try Supabase first
      final success = await _supabaseService.updateOrder(updatedOrder);
      if (success) {
        final index = _ordersCache.indexWhere((o) => o.id == updatedOrder.id);
        if (index != -1) {
          _ordersCache[index] = updatedOrder;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating order in Supabase: $e');
      final index = _ordersCache.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _ordersCache[index] = Order(
          id: order.id,
          orderNumber: order.orderNumber,
          customerId: order.customerId,
          clientName: order.clientName,
          advancePaid: order.advancePaid,
          dueDate: order.dueDate,
          dispatchDate: order.dispatchDate,
          isAdvancePaid: order.isAdvancePaid,
          advancePaymentDate: order.advancePaymentDate,
          afterDispatchDays: order.afterDispatchDays,
          finalDueDate: order.finalDueDate,
          finalPaymentDate: order.finalPaymentDate,
          orderStatus: order.orderStatus,
          paymentStatus: order.paymentStatus,
          productionStatus: order.productionStatus,
          createdBy: order.createdBy,
          createdAt: order.createdAt,
          updatedAt: DateTime.now(),
          totalAmount: order.totalAmount,
        );
        return true;
      }
      return false;
    }
  }

  // Delete an order
  Future<bool> deleteOrder(int orderId) async {
    try {
      // Try Supabase first
      final success = await _supabaseService.deleteOrder(orderId);
      if (success) {
        // Remove from cache
        _ordersCache.removeWhere((o) => o.id == orderId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting order from Supabase: $e');
      // Remove from cache for web
      _ordersCache.removeWhere((o) => o.id == orderId);
      return true; // Always return true for cache operations
    }
  } // Get order by ID

  Future<Order?> getOrderById(int id) async {
    try {
      // Try Supabase first
      final orders = await _supabaseService.getOrders();
      return orders.firstWhere((order) => order.id == id);
    } catch (e) {
      debugPrint('Error getting order by ID from Supabase: $e');
      // Search in cache
      try {
        return _ordersCache.firstWhere((order) => order.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  // Get orders by status
  Future<List<Order>> getOrdersByStatus(String status) async {
    try {
      final orders = await getOrders();
      return orders.where((order) => order.orderStatus == status).toList();
    } catch (e) {
      debugPrint('Error getting orders by status: $e');
      return [];
    }
  }

  // Get orders by payment status
  Future<List<Order>> getOrdersByPaymentStatus(String paymentStatus) async {
    try {
      final orders = await getOrders();
      return orders
          .where((order) => order.paymentStatus == paymentStatus)
          .toList();
    } catch (e) {
      debugPrint('Error getting orders by payment status: $e');
      return [];
    }
  }

  // Get overdue orders
  Future<List<Order>> getOverdueOrders() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final orders = await getOrders();
      return orders
          .where(
            (order) =>
                order.dueDate.compareTo(today) < 0 &&
                order.paymentStatus != 'paid',
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting overdue orders: $e');
      return [];
    }
  }

  // Generate unique order number
  Future<String> _generateOrderNumber() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Get count of orders created today from cache or Supabase
    try {
      final orders = await getOrders();
      final todayOrders =
          orders
              .where(
                (order) =>
                    order.createdAt != null &&
                    order.createdAt!.year == now.year &&
                    order.createdAt!.month == now.month &&
                    order.createdAt!.day == now.day,
              )
              .toList();

      final orderCount = todayOrders.length + 1;
      return 'ORD-$dateStr-${orderCount.toString().padLeft(3, '0')}';
    } catch (e) {
      // Fallback to timestamp-based ID
      return 'ORD-$dateStr-${now.millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  // Customer management methods
  Future<List<Customer>> getCustomers() async {
    try {
      // Try Supabase first
      return await _supabaseService.getCustomers();
    } catch (e) {
      debugPrint('Error getting customers from Supabase: $e');
      // Return cached customers
      return _customersCache;
    }
  }

  Future<Customer?> addCustomer(Customer customer) async {
    try {
      customer.createdAt = DateTime.now();
      customer.updatedAt = DateTime.now();

      // Try Supabase first
      final addedCustomer = await _supabaseService.addCustomer(customer);
      if (addedCustomer != null) {
        // Update cache
        _customersCache.add(addedCustomer);
        return addedCustomer;
      }
      return null;
    } catch (e) {
      debugPrint('Error adding customer to Supabase: $e');
      // Add to cache for web
      customer.id = DateTime.now().millisecondsSinceEpoch; // Generate ID
      _customersCache.add(customer);
      return customer;
    }
  }

  Future<Customer?> getCustomerById(int id) async {
    try {
      // Try Supabase first
      final customers = await _supabaseService.getCustomers();
      return customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      debugPrint('Error getting customer by ID from Supabase: $e');
      // Search in cache
      try {
        return _customersCache.firstWhere((customer) => customer.id == id);
      } catch (e) {
        return null;
      }
    }
  } // Initialize with some default data if database is empty

  Future<void> initializeDefaultData() async {
    try {
      // Sign in anonymously to Supabase if not authenticated
      if (!_supabaseService.isAuthenticated) {
        final ok = await _supabaseService.signInAnonymously();
        if (!ok) {
          // If anonymous disabled (422), just log and continue with cache-only mode
          debugPrint(
            'Anonymous auth not enabled; proceeding with local cache fallback.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error authenticating with Supabase: $e');
    }

    final orders = await getOrders();
    if (orders.isEmpty) {
      // Add some default customers
      final customer1 = Customer(companyName: 'ABC Corp');
      final customer2 = Customer(companyName: 'XYZ Industries');

      final addedCustomer1 = await addCustomer(customer1);
      final addedCustomer2 = await addCustomer(customer2);

      if (addedCustomer1 != null && addedCustomer2 != null) {
        // Add some default orders (products will be added as order_items)
        await addOrder(
          Order(
            customerId: addedCustomer1.id,
            clientName: addedCustomer1.companyName,
            advancePaid: 15000.0,
            dueDate: '2025-10-05',
            isAdvancePaid: true,
            afterDispatchDays: 7,
            finalDueDate: '2025-10-12',
            paymentStatus: 'paid',
            totalAmount: 15000.0,
          ),
        );

        await addOrder(
          Order(
            customerId: addedCustomer2.id,
            clientName: addedCustomer2.companyName,
            advancePaid: 10000.0,
            dueDate: '2025-10-08',
            isAdvancePaid: true,
            afterDispatchDays: 5,
            finalDueDate: '2025-10-13',
            paymentStatus: 'partial',
            totalAmount: 25000.0,
          ),
        );
        // TODO: Add OrderItem creation logic for these orders if needed
      }
    }
  }
}
