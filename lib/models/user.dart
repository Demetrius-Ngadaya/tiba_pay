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

  var createdBy;

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
    );
  }

  String get fullName {
    return middleName?.isNotEmpty ?? false
        ? '$firstName $middleName $lastName'
        : '$firstName $lastName';
  }
}