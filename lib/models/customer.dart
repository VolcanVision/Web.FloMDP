class Customer {
  int? id;
  String companyName;
  String? contactPerson;
  String? email;
  String? phone;
  String? address;
  DateTime? createdAt;
  DateTime? updatedAt;
  bool isActive;

  Customer({
    this.id,
    required this.companyName,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  // Convert Customer to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_name': companyName,
      'contact_person': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive, // Use boolean for Supabase
    };
  }

  // Create Customer from Map (database result)
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      companyName: map['company_name'] ?? '',
      contactPerson: map['contact_person'],
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      isActive: map['is_active'] ?? true, // Handle boolean for Supabase
    );
  }
}
