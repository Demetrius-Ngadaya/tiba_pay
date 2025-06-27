import 'package:intl/intl.dart';

class PaymentItem {
  final String itemId;
  final String itemName;
  final String itemCategory;
  final double amount;
  int quantity;
  final String? department;

  PaymentItem({
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.amount,
    this.quantity = 1,
    this.department,
  });

  // For API communication
  Map<String, dynamic> toApiMap() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'item_category': itemCategory,
      'amount': amount,
      'quantity': quantity,
      'department': department,
      'total': total,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemCategory': itemCategory,
      'amount': amount,
      'quantity': quantity,
      'department': department,
    };
  }

  PaymentItem copyWith({
    String? itemId,
    String? itemName,
    String? itemCategory,
    double? amount,
    int? quantity,
    String? department,
  }) {
    return PaymentItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemCategory: itemCategory ?? this.itemCategory,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      department: department ?? this.department,
    );
  }

  double get total => amount * quantity;

  @override
  String toString() {
    return '$itemName (${quantity}x ${amount.toStringAsFixed(2)})';
  }
}

class Payment {
  final String paymentId;
  final DateTime paymentDate;
  final String patientId;
  final String createdBy;
  final int createdById;
  final String sponsor;
  final PaymentItem item;
  final bool isSynced;
  final String? department;
  final String? status;
  final String? patientName;
  final String? phoneNumber;

  Payment({
    required this.paymentId,
    required this.paymentDate,
    required this.patientId,
    required this.createdBy,
    required this.createdById,
    required this.sponsor,
    required this.item,
    this.isSynced = false,
    this.department,
    this.status,
    this.patientName,
    this.phoneNumber,
  });

  // For API communication
  Map<String, dynamic> toApiMap() {
    return {
      'payment_id': paymentId,
      'payment_date': paymentDate.toIso8601String(),
      'patient_id': patientId,
      'created_by': createdBy,
      'created_by_id': createdById,
      'sponsor': sponsor,
      'item': item.toApiMap(),
      'department': department,
      'status': status ?? 'completed',
      'patient_name': patientName,
      'phone_number': phoneNumber,
      'total_amount': totalAmount,
      'receipt_number': receiptNumber,
    };
  }

  // For local database storage
  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'paymentDate': paymentDate.toIso8601String(),
      'patientId': patientId,
      'createdBy': createdBy,
      'createdById': createdById,
      'sponsor': sponsor,
      'itemId': item.itemId,
      'itemName': item.itemName,
      'itemCategory': item.itemCategory,
      'amount': item.amount,
      'quantity': item.quantity,
      'isSynced': isSynced ? 1 : 0,
      'department': department ?? item.department,
      'status': status,
      'patientName': patientName,
      'phoneNumber': phoneNumber,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      paymentId: map['paymentId'] ?? '',
      paymentDate: DateTime.parse(map['paymentDate'] ?? DateTime.now().toIso8601String()),
      patientId: map['patientId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdById: map['createdById'] ?? 0,
      sponsor: map['sponsor'] ?? '',
      item: PaymentItem(
        itemId: map['itemId'] ?? '',
        itemName: map['itemName'] ?? '',
        itemCategory: map['itemCategory'] ?? '',
        amount: (map['amount'] is int ? (map['amount'] as int).toDouble() : map['amount']) ?? 0.0,
        quantity: map['quantity'] ?? 1,
        department: map['department'],
      ),
      isSynced: map['isSynced'] == 1,
      department: map['department'],
      status: map['status'],
      patientName: map['patientName'],
      phoneNumber: map['phoneNumber'],
    );
  }

  Payment copyWith({
    String? paymentId,
    DateTime? paymentDate,
    String? patientId,
    String? createdBy,
    int? createdById,
    String? sponsor,
    PaymentItem? item,
    bool? isSynced,
    String? department,
    String? status,
    String? patientName,
    String? phoneNumber,
  }) {
    return Payment(
      paymentId: paymentId ?? this.paymentId,
      paymentDate: paymentDate ?? this.paymentDate,
      patientId: patientId ?? this.patientId,
      createdBy: createdBy ?? this.createdBy,
      createdById: createdById ?? this.createdById,
      sponsor: sponsor ?? this.sponsor,
      item: item ?? this.item,
      isSynced: isSynced ?? this.isSynced,
      department: department ?? this.department,
      status: status ?? this.status,
      patientName: patientName ?? this.patientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  double get totalAmount => item.total;
  
  String get formattedDate => DateFormat('yyyy-MM-dd HH:mm').format(paymentDate);
  
  String get receiptNumber => 'REC-${paymentId.substring(0, 8).toUpperCase()}';

  @override
  String toString() {
    return 'Payment #$paymentId ($formattedDate) - ${totalAmount.toStringAsFixed(2)}';
  }
}