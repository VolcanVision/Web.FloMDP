class Shipment {
  int? id;
  int orderId;
  String? shipmentName;
  String shippedAt;
  String status; // 'pending', 'in_transit', 'delivered', 'cancelled'
  String? shipmentIncharge;
  String? shippingCompany;
  String? vehicleDetails;
  String? driverContactNumber;
  String? location;
  DateTime? deliveredAt;
  DateTime? createdAt;

  Shipment({
    this.id,
    required this.orderId,
    this.shipmentName,
    required this.shippedAt,
    this.status = 'in_transit',
    this.shipmentIncharge,
    this.shippingCompany,
    this.vehicleDetails,
    this.driverContactNumber,
    this.location,
    this.deliveredAt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'shipment_name': shipmentName,
      'shipped_at': shippedAt,
      'status': status,
      'shipment_incharge': shipmentIncharge,
      'shipping_company': shippingCompany,
      'vehicle_details': vehicleDetails,
      'driver_contact_number': driverContactNumber,
      'location': location,
      'delivered_at': deliveredAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Shipment.fromMap(Map<String, dynamic> map) {
    return Shipment(
      id: map['id'],
      orderId: map['order_id'],
      shipmentName: map['shipment_name'],
      shippedAt: map['shipped_at'] ?? '',
      status: map['status'] ?? 'in_transit',
      shipmentIncharge: map['shipment_incharge'],
      shippingCompany: map['shipping_company'],
      vehicleDetails: map['vehicle_details'],
      driverContactNumber: map['driver_contact_number'],
      location: map['location'],
      deliveredAt: map['delivered_at'] != null
          ? DateTime.parse(map['delivered_at'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }
}
