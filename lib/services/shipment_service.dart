import 'base_supabase_service.dart';
import '../models/shipment.dart';
import '../models/order_history.dart';

class ShipmentService extends BaseSupabaseService {
  String? lastError;

  Future<Shipment?> create(Shipment shipment) async {
    lastError = null;
    try {
      final data =
          shipment.toMap()
            ..remove('id')
            ..remove('created_at');

      final res = await client.from('shipments').insert(data).select().single();

      return Shipment.fromMap(res);
    } catch (e) {
      lastError = 'Failed to create shipment: $e';
      return null;
    }
  }

  Future<List<OrderHistory>> getOrderHistory() async {
    try {
      final res = await client
          .from('v_order_history')
          .select()
          .order('shipped_at', ascending: false);

      final list = (res as List).map((e) => OrderHistory.fromMap(e)).toList();
      // finalPaymentDate is computed inside OrderHistory.fromMap()
      // (prefers dispatch_date + after_dispatch_days when available)
      return list;
    } catch (e) {
      // If the DB view `v_order_history` is missing (schema drift), fall back
      // to constructing a lightweight history list from `shipments` + `orders`
      // to keep the UI working.
      lastError = 'Failed to fetch v_order_history: $e';
      try {
        final shipments = await client
            .from('shipments')
            .select()
            .order('shipped_at', ascending: false)
            .limit(30);

        final List<OrderHistory> fallback = [];
        for (final s in (shipments as List)) {
          try {
            final orderId = s['order_id'];
            Map<String, dynamic>? orderMap;
            if (orderId != null) {
              try {
                orderMap =
                    await client
                        .from('orders')
                        .select()
                        .eq('id', orderId)
                        .single();
              } catch (_) {
                orderMap = null;
              }
            }

            // Fetch order items for a simple products list (best-effort)
            String? productsList;
            if (orderMap != null) {
              try {
                final items = await client
                    .from('order_items')
                    .select('product_name')
                    .eq('order_id', orderMap['id']);
                final itemsList = items as List?;
                if (itemsList != null && itemsList.isNotEmpty) {
                  productsList = itemsList
                      .map((i) => i['product_name']?.toString() ?? '')
                      .where((s) => s.isNotEmpty)
                      .join(', ');
                }
              } catch (_) {
                productsList = null;
              }
            }

            final totalAmount =
                (orderMap != null && orderMap['total_amount'] != null)
                    ? (orderMap['total_amount'] as num).toDouble()
                    : 0.0;
            final advancePaid =
                (orderMap != null && orderMap['advance_paid'] != null)
                    ? (orderMap['advance_paid'] as num).toDouble()
                    : 0.0;

            final shipmentName =
                s['shipment_name'] ?? s['shipment_no'] ?? s['batch_no'];
            final shipmentNotes = s['notes'] ?? s['note'];
            // Try to fetch production batch info (prefer production_batches over order/report fields)
            String? prodBatchNo;
            String? prodBatchDetails;
            try {
              final pb = await client
                  .from('production_batches')
                  .select('batch_no, details')
                  .eq('order_id', orderMap?['id'])
                  .order('created_at', ascending: false)
                  .limit(1);
              final pbList = pb as List?;
              if (pbList != null && pbList.isNotEmpty) {
                prodBatchNo = pbList.first['batch_no']?.toString();
                prodBatchDetails = pbList.first['details']?.toString();
              }
            } catch (_) {
              // ignore - best-effort
            }

            // compute final payment date: if final_payment_date exists and
            // after_dispatch_days > 0, add the days to it. Otherwise compute
            // from dispatch_date + after_dispatch_days when available.
            String? finalPaymentDate;
            try {
              final days =
                  orderMap != null && orderMap['after_dispatch_days'] != null
                      ? (orderMap['after_dispatch_days'] is int
                          ? orderMap['after_dispatch_days'] as int
                          : int.tryParse(
                                orderMap['after_dispatch_days']?.toString() ??
                                    '',
                              ) ??
                              0)
                      : 0;

              if (orderMap != null && orderMap['final_payment_date'] != null) {
                // Try to parse and add days if needed
                if (days > 0) {
                  final fp = DateTime.tryParse(
                    orderMap['final_payment_date'].toString(),
                  );
                  if (fp != null) {
                    finalPaymentDate =
                        fp
                            .add(Duration(days: days))
                            .toIso8601String()
                            .split('T')[0];
                  } else {
                    finalPaymentDate =
                        orderMap['final_payment_date']?.toString();
                  }
                } else {
                  finalPaymentDate = orderMap['final_payment_date']?.toString();
                }
              } else if (orderMap != null &&
                  orderMap['dispatch_date'] != null &&
                  days > 0) {
                final dispatch = DateTime.tryParse(
                  orderMap['dispatch_date'].toString(),
                );
                if (dispatch != null) {
                  finalPaymentDate =
                      dispatch
                          .add(Duration(days: days))
                          .toIso8601String()
                          .split('T')[0];
                }
              }
            } catch (_) {
              finalPaymentDate =
                  orderMap != null ? orderMap['final_payment_date'] : null;
            }

            final oh = OrderHistory(
              id:
                  orderMap != null
                      ? (orderMap['id'] is int
                          ? orderMap['id']
                          : (int.tryParse(orderMap['id']?.toString() ?? '') ??
                              0))
                      : null,
              orderNumber: orderMap != null ? orderMap['order_number'] : null,
              clientName: orderMap != null ? orderMap['client_name'] : null,
              productsList: productsList,
              dueDate: orderMap != null ? orderMap['due_date'] : null,
              dispatchDate: orderMap != null ? orderMap['dispatch_date'] : null,
              totalAmount: totalAmount,
              advancePaid: advancePaid,
              advancePaymentDate:
                  orderMap != null ? orderMap['advance_payment_date'] : null,
              finalPaymentDate:
                  finalPaymentDate ??
                  (orderMap != null ? orderMap['final_payment_date'] : null),
              afterDispatchDays:
                  orderMap != null
                      ? (orderMap['after_dispatch_days'] is int
                          ? orderMap['after_dispatch_days']
                          : (int.tryParse(
                                orderMap['after_dispatch_days']?.toString() ??
                                    '',
                              ) ??
                              0))
                      : 0,
              // prefer production_batches -> shipment -> order fields
              batchNo:
                  prodBatchNo ??
                  shipmentName ??
                  orderMap?['batch_no'] ??
                  orderMap?['shipment_name'],
              batchDetails:
                  prodBatchDetails ??
                  shipmentNotes ??
                  orderMap?['batch_details'] ??
                  orderMap?['notes'],
              shippedAt:
                  s['shipped_at'] != null ? s['shipped_at'].toString() : null,
              paymentDueDate:
                  orderMap != null ? orderMap['payment_due_date'] : null,
              pendingAmount: (totalAmount - advancePaid),
              createdAt:
                  orderMap != null && orderMap['created_at'] != null
                      ? DateTime.tryParse(orderMap['created_at'].toString())
                      : null,
            );

            fallback.add(oh);
          } catch (_) {
            // ignore per-item errors and continue
            continue;
          }
        }

        return fallback;
      } catch (e2) {
        lastError = 'Fallback history fetch failed: $e2';
        return [];
      }
    }
  }
}
