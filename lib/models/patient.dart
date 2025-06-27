class Patient {
  final String patientNumber;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String sponsor;
  final DateTime createdAt;
  final String? address;
  final String? phoneNumber;
  final String createdBy;
  final bool isSynced;

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
    this.isSynced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fullName => '$firstName ${middleName ?? ''} $lastName'.trim();

  // For local database storage
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
      'isSynced': isSynced ? 1 : 0,
    };
  }

  // For API communication
  Map<String, dynamic> toApiMap() {
    return {
      'patient_number': patientNumber,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'sponsor': sponsor,
      'created_at': createdAt.toIso8601String(),
      'address': address,
      'phone_number': phoneNumber,
      'created_by': createdBy,
      'full_name': fullName,
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
      isSynced: map['isSynced'] == 1,
    );
  }

  // For creating updated copies
  Patient copyWith({
    String? patientNumber,
    String? firstName,
    String? middleName,
    String? lastName,
    String? sponsor,
    DateTime? createdAt,
    String? address,
    String? phoneNumber,
    String? createdBy,
    bool? isSynced,
  }) {
    return Patient(
      patientNumber: patientNumber ?? this.patientNumber,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      sponsor: sponsor ?? this.sponsor,
      createdAt: createdAt ?? this.createdAt,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdBy: createdBy ?? this.createdBy,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  String toString() {
    return 'Patient($patientNumber: $fullName)';
  }
}