class Patient {
  final String patientNumber;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String sponsor;
  final DateTime createdAt;
  final String? address;
  final String? phoneNumber;
  final String createdBy; // Changed from int to String

  Patient({
    required this.patientNumber,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.sponsor,
    DateTime? createdAt,
    this.address,
    this.phoneNumber,
    required this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fullName => '$firstName ${middleName ?? ''} $lastName'.trim();

  Map<String, dynamic> toMap() {
    return {
      'patientNumber': patientNumber,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'sponsor': sponsor,
      'created_at': createdAt.toIso8601String(),
      'address': address,
      'phoneNumber': phoneNumber,
      'created_by': createdBy,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientNumber: map['patientNumber'] ?? '',
      firstName: map['firstName'] ?? '',
      middleName: map['middleName'],
      lastName: map['lastName'] ?? '',
      sponsor: map['sponsor'] ?? 'CASH SELF REFERRAL',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
      address: map['address'],
      phoneNumber: map['phoneNumber'],
      createdBy: map['created_by'] ?? 'System',
    );
  }
}