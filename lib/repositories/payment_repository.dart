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

  Future<List<Payment>> getAllPaymentsWithDetails({int limit = 10, int offset = 0}) async {
    final db = await dbHelper.database;
    
    final payments = await db.query(
      'payments',
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

  Future<List<Payment>> getPaymentsByUser(int userId, {int limit = 10, int offset = 0}) async {
    final db = await dbHelper.database;
    
    final payments = await db.query(
      'payments',
      where: 'createdById = ?',
      whereArgs: [userId],
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

  Future<int> getPaymentsCount({int? userId}) async {
    final db = await dbHelper.database;
    final count = userId == null
        ? await db.rawQuery('SELECT COUNT(*) FROM payments')
        : await db.rawQuery('SELECT COUNT(*) FROM payments WHERE createdById = ?', [userId]);
    return Sqflite.firstIntValue(count) ?? 0;
  }

  Future<double> getTotalPaymentsAmount({int? userId}) async {
    final db = await dbHelper.database;
    final result = userId == null
        ? await db.rawQuery('SELECT SUM(amount * quantity) FROM payments')
        : await db.rawQuery('SELECT SUM(amount * quantity) FROM payments WHERE createdById = ?', [userId]);
    return result.first.values.first as double? ?? 0.0;
  }
}