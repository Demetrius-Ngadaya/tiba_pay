import 'package:sqflite/sqflite.dart';
import '../models/payment.dart';
import '../utils/database_helper.dart';

class PaymentRepository {
  final DatabaseHelper dbHelper; 

  PaymentRepository({required this.dbHelper});

  Future<int> createPayment(Payment payment) async {
    final db = await dbHelper.database;
    return await db.insert(
      'payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Payment>> getAllPaymentsWithDetails({
    int? limit,
    int? offset,
    String? searchQuery,
    String? sponsor,
    String? category,
    String? createdBy,
    String? patientName,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = '1 = 1';
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += '''
        AND (payments.patientId LIKE ? 
        OR payments.patientName LIKE ? 
        OR payments.receiptNumber LIKE ? 
        OR payments.itemName LIKE ? 
        OR payments.sponsor LIKE ? 
        OR payments.itemCategory LIKE ? 
        OR payments.createdBy LIKE ?)
      ''';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll(List.filled(7, searchTerm));
    }

    if (sponsor != null && sponsor.isNotEmpty) {
      where += ' AND payments.sponsor LIKE ?';
      whereArgs.add('%$sponsor%');
    }

    if (category != null && category.isNotEmpty) {
      where += ' AND payments.itemCategory LIKE ?';
      whereArgs.add('%$category%');
    }

    if (createdBy != null && createdBy.isNotEmpty) {
      where += ' AND payments.createdBy LIKE ?';
      whereArgs.add('%$createdBy%');
    }

    if (patientName != null && patientName.isNotEmpty) {
      where += ' AND payments.patientName LIKE ?';
      whereArgs.add('%$patientName%');
    }

    if (patientId != null && patientId.isNotEmpty) {
      where += ' AND payments.patientId LIKE ?';
      whereArgs.add('%$patientId%');
    }

    if (startDate != null) {
      where += ' AND payments.paymentDate >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND payments.paymentDate <= ?';
      whereArgs.add(endDate.add(const Duration(days: 1)).millisecondsSinceEpoch);
    }

    final payments = await db.query(
      'payments',
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'paymentDate DESC',
    );

    if (payments.isEmpty) return [];

    // Batch fetch related patient data
    final patientNumbers = payments.map((p) => p['patientId'] as String).toSet().toList();

    final patients = await db.query(
      'patients',
      where: 'patientNumber IN (${List.filled(patientNumbers.length, '?').join(',')})',
      whereArgs: patientNumbers,
    );

    // Create patient lookup map
    final patientMap = { for (var p in patients) p['patientNumber'] as String: p };

    return payments.map((payment) {
      final patientData = patientMap[payment['patientId'] as String];
      
      return Payment.fromMap({
        ...payment,
        'patientName': payment['patientName'] ?? 
          (patientData != null ? '${patientData['firstName']} ${patientData['lastName']}' : 'Unknown Patient'),
        'phoneNumber': payment['phoneNumber'] ?? patientData?['phoneNumber'] as String?,
      });
    }).toList();
  }

  Future<List<Payment>> getPaymentsByUser(
    int userId, {
    int? limit,
    int? offset,
    String? searchQuery,
    String? sponsor,
    String? category,
    String? createdBy,
    String? patientName,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = 'createdById = ?';
    final whereArgs = <dynamic>[userId];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += '''
        AND (payments.patientId LIKE ? 
        OR payments.patientName LIKE ? 
        OR payments.receiptNumber LIKE ? 
        OR payments.itemName LIKE ? 
        OR payments.sponsor LIKE ? 
        OR payments.itemCategory LIKE ? 
        OR payments.createdBy LIKE ?)
      ''';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll(List.filled(7, searchTerm));
    }

    if (sponsor != null && sponsor.isNotEmpty) {
      where += ' AND payments.sponsor LIKE ?';
      whereArgs.add('%$sponsor%');
    }

    if (category != null && category.isNotEmpty) {
      where += ' AND payments.itemCategory LIKE ?';
      whereArgs.add('%$category%');
    }

    if (createdBy != null && createdBy.isNotEmpty) {
      where += ' AND payments.createdBy LIKE ?';
      whereArgs.add('%$createdBy%');
    }

    if (patientName != null && patientName.isNotEmpty) {
      where += ' AND payments.patientName LIKE ?';
      whereArgs.add('%$patientName%');
    }

    if (patientId != null && patientId.isNotEmpty) {
      where += ' AND payments.patientId LIKE ?';
      whereArgs.add('%$patientId%');
    }

    if (startDate != null) {
      where += ' AND payments.paymentDate >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND payments.paymentDate <= ?';
      whereArgs.add(endDate.add(const Duration(days: 1)).millisecondsSinceEpoch);
    }

    final payments = await db.query(
      'payments',
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'paymentDate DESC',
    );

    if (payments.isEmpty) return [];

    // Similar patient data fetching as in getAllPaymentsWithDetails
    final patientNumbers = payments.map((p) => p['patientId'] as String).toSet().toList();

    final patients = await db.query(
      'patients',
      where: 'patientNumber IN (${List.filled(patientNumbers.length, '?').join(',')})',
      whereArgs: patientNumbers,
    );

    final patientMap = { for (var p in patients) p['patientNumber'] as String: p };

    return payments.map((payment) {
      final patientData = patientMap[payment['patientId'] as String];
      
      return Payment.fromMap({
        ...payment,
        'patientName': payment['patientName'] ?? 
          (patientData != null ? '${patientData['firstName']} ${patientData['lastName']}' : 'Unknown Patient'),
        'phoneNumber': payment['phoneNumber'] ?? patientData?['phoneNumber'] as String?,
      });
    }).toList();
  }

  Future<List<Payment>> getPaymentsByPatient(String patientId) async {
    final db = await dbHelper.database;
    
    final payments = await db.query(
      'payments',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'paymentDate DESC',
    );

    return payments.map((payment) => Payment.fromMap(payment)).toList();
  }

  Future<int> getPaymentsCount({
    int? userId,
    String? searchQuery,
    String? sponsor,
    String? category,
    String? createdBy,
    String? patientName,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = userId == null ? '1 = 1' : 'createdById = ?';
    final whereArgs = <dynamic>[];
    if (userId != null) whereArgs.add(userId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += '''
        AND (payments.patientId LIKE ? 
        OR payments.patientName LIKE ? 
        OR payments.receiptNumber LIKE ? 
        OR payments.itemName LIKE ? 
        OR payments.sponsor LIKE ? 
        OR payments.itemCategory LIKE ? 
        OR payments.createdBy LIKE ?)
      ''';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll(List.filled(7, searchTerm));
    }

    if (sponsor != null && sponsor.isNotEmpty) {
      where += ' AND payments.sponsor LIKE ?';
      whereArgs.add('%$sponsor%');
    }

    if (category != null && category.isNotEmpty) {
      where += ' AND payments.itemCategory LIKE ?';
      whereArgs.add('%$category%');
    }

    if (createdBy != null && createdBy.isNotEmpty) {
      where += ' AND payments.createdBy LIKE ?';
      whereArgs.add('%$createdBy%');
    }

    if (patientName != null && patientName.isNotEmpty) {
      where += ' AND payments.patientName LIKE ?';
      whereArgs.add('%$patientName%');
    }

    if (patientId != null && patientId.isNotEmpty) {
      where += ' AND payments.patientId LIKE ?';
      whereArgs.add('%$patientId%');
    }

    if (startDate != null) {
      where += ' AND payments.paymentDate >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND payments.paymentDate <= ?';
      whereArgs.add(endDate.add(const Duration(days: 1)).millisecondsSinceEpoch);
    }

    final count = await db.rawQuery('SELECT COUNT(*) FROM payments WHERE $where', whereArgs);
    return Sqflite.firstIntValue(count) ?? 0;
  }

  Future<double> getTotalPaymentsAmount({
    int? userId,
    String? searchQuery,
    String? sponsor,
    String? category,
    String? createdBy,
    String? patientName,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = userId == null ? '1 = 1' : 'createdById = ?';
    final whereArgs = <dynamic>[];
    if (userId != null) whereArgs.add(userId);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += '''
        AND (payments.patientId LIKE ? 
        OR payments.patientName LIKE ? 
        OR payments.receiptNumber LIKE ? 
        OR payments.itemName LIKE ? 
        OR payments.sponsor LIKE ? 
        OR payments.itemCategory LIKE ? 
        OR payments.createdBy LIKE ?)
      ''';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll(List.filled(7, searchTerm));
    }

    if (sponsor != null && sponsor.isNotEmpty) {
      where += ' AND payments.sponsor LIKE ?';
      whereArgs.add('%$sponsor%');
    }

    if (category != null && category.isNotEmpty) {
      where += ' AND payments.itemCategory LIKE ?';
      whereArgs.add('%$category%');
    }

    if (createdBy != null && createdBy.isNotEmpty) {
      where += ' AND payments.createdBy LIKE ?';
      whereArgs.add('%$createdBy%');
    }

    if (patientName != null && patientName.isNotEmpty) {
      where += ' AND payments.patientName LIKE ?';
      whereArgs.add('%$patientName%');
    }

    if (patientId != null && patientId.isNotEmpty) {
      where += ' AND payments.patientId LIKE ?';
      whereArgs.add('%$patientId%');
    }

    if (startDate != null) {
      where += ' AND payments.paymentDate >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND payments.paymentDate <= ?';
      whereArgs.add(endDate.add(const Duration(days: 1)).millisecondsSinceEpoch);
    }

    final result = await db.rawQuery('SELECT SUM(amount * quantity) FROM payments WHERE $where', whereArgs);
    return result.first.values.first as double? ?? 0.0;
  }
}