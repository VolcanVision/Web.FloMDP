class OrderHistory {
  int? id;
  String? orderNumber;
  String? clientName;
  String? productsList;
  String? dueDate;
  String? dispatchDate;
  double totalAmount;
  double advancePaid;
  String? advancePaymentDate;
  String? finalPaymentDate;
  int afterDispatchDays;
  String? batchNo;
  String? batchDetails;
  String? shippedAt;
  String? paymentDueDate;
  double pendingAmount;
  String? destination; // Added location field
  String? status; // Added status field
  DateTime? createdAt;
  // Shipment details
  String? shippingCompany;
  String? vehicleDetails;
  String? driverContact;
  String? shipmentIncharge;

  OrderHistory({
    this.id,
    this.orderNumber,
    this.clientName,
    this.productsList,
    this.destination, // Added location field
    this.status, // Added status field
    this.dueDate,
    this.dispatchDate,
    required this.totalAmount,
    required this.advancePaid,
    this.advancePaymentDate,
    this.finalPaymentDate,
    this.afterDispatchDays = 0,
    this.batchNo,
    this.batchDetails,
    this.shippedAt,
    this.paymentDueDate,
    required this.pendingAmount,
    this.createdAt,
    this.shippingCompany,
    this.vehicleDetails,
    this.driverContact,
    this.shipmentIncharge,
  });

  factory OrderHistory.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      if (v is num) return v.toInt();
      return fallback;
    }

    // Compute a safe integer for after-dispatch days
    final afd = parseInt(map['after_dispatch_days'], 0);

    // Start with any explicit final_payment_date from the map
    String? computedFinal = map['final_payment_date'];

    // If dispatch_date and after-dispatch-days are present, prefer computing
    // finalPaymentDate as dispatch_date + afd. This guarantees a consistent
    // value regardless of which service/path created the map.
    if (afd > 0 && map['dispatch_date'] != null) {
      try {
        final d = map['dispatch_date'];
        DateTime? dispatchDt;
        if (d is String) {
          dispatchDt = DateTime.tryParse(d);
        } else if (d is DateTime)
          dispatchDt = d;
        else if (d is int)
          dispatchDt = DateTime.fromMillisecondsSinceEpoch(d);
        else if (d is double)
          dispatchDt = DateTime.fromMillisecondsSinceEpoch(d.toInt());

        if (dispatchDt != null) {
          computedFinal =
              dispatchDt
                  .add(Duration(days: afd))
                  .toIso8601String()
                  .split('T')[0];
        }
      } catch (_) {
        // ignore parse errors and fall back to provided value
      }
    }

    return OrderHistory(
      id: map['id'] is int ? map['id'] : parseInt(map['id'], 0),
      orderNumber: map['order_number'],
      clientName: map['client_name'],
      productsList: map['products_list'],
      destination: map['destination'] ?? map['delivery_location'], 
      status: map['status'],
      dueDate: map['due_date'],
      dispatchDate: map['dispatch_date'],
      totalAmount:
          (map['total_amount'] ?? map['total_cost'])?.toDouble() ?? 0.0,
      advancePaid: map['advance_paid']?.toDouble() ?? 0.0,
      advancePaymentDate: map['advance_payment_date'],
      finalPaymentDate: computedFinal,
      afterDispatchDays: afd,
      batchNo: map['batch_no'],
      batchDetails: map['batch_details'],
      shippedAt: () {
        final v = map['shipped_at'];
        if (v == null) return null;
        if (v is String) return v;
        if (v is DateTime) return v.toIso8601String();
        if (v is int) {
          return DateTime.fromMillisecondsSinceEpoch(v).toIso8601String();
        }
        if (v is double) {
          return DateTime.fromMillisecondsSinceEpoch(
            v.toInt(),
          ).toIso8601String();
        }
        return v.toString();
      }(),
      paymentDueDate: map['payment_due_date'],
      pendingAmount: map['pending_amount']?.toDouble() ?? 0.0,
      createdAt: () {
        final v = map['created_at'];
        if (v == null) return null;
        if (v is DateTime) return v;
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        if (v is String) {
          final parsedInt = int.tryParse(v);
          if (parsedInt != null) {
            return DateTime.fromMillisecondsSinceEpoch(parsedInt);
          }
          return DateTime.tryParse(v);
        }
        return null;
      }(),
      shippingCompany: map['shipping_company'],
      vehicleDetails: map['vehicle_details'],
      driverContact: map['driver_contact_number'] ?? map['driver_contact'],
      shipmentIncharge: map['shipment_incharge'],
    );
  }
}
