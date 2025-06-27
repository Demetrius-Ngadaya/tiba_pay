class User {
  final int? userId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String username;
  final String passwordHash;
  final String role;
  final String status;
  final String createdAt;
  final String createdBy; // Added createdBy field
  final String authToken; // Add this field

  User({
    this.userId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.createdBy, // Added to constructor
    this.authToken = '',// Make optional with default empty string
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'status': status,
      'created_at': createdAt,
      'created_by': createdBy, // Added to map
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['user_id'],
      firstName: map['firstName'],
      middleName: map['middleName'],
      lastName: map['lastName'],
      username: map['username'],
      passwordHash: map['password_hash'],
      role: map['role'],
      status: map['status'],
      createdAt: map['created_at'],
      createdBy: map['created_by'] ?? 'system', // Added with default
      authToken: map['auth_token'] ?? '', // Add this line
    );
  }

  String get fullName {
    return middleName?.isNotEmpty ?? false
        ? '$firstName $middleName $lastName'
        : '$firstName $lastName';
  }
}