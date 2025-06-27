import 'package:tiba_pay/models/payment.dart';
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/models/sync_log.dart';
import 'package:tiba_pay/services/sync_service.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class SyncRepository {
  final DatabaseHelper dbHelper;
  final SyncService syncService;

  SyncRepository({
    required this.dbHelper,
    required this.syncService,
  });

  Future<SyncResult> syncUnsyncedData(User user) async {
    final db = await dbHelper.database;

    // Start transaction
    await db.execute('BEGIN TRANSACTION');

    try {
      // Get unsynced patients
      final patientMaps = await db.query(
        'patients',
        where: 'isSynced = ?',  
        whereArgs: [0],
      );
      final patients = patientMaps.map((map) => Patient.fromMap(map)).toList();

      // Get unsynced payments
      final paymentMaps = await db.query(
        'payments',
        where: 'isSynced = ?',
        whereArgs: [0],
      );
      final payments = paymentMaps.map((map) => Payment.fromMap(map)).toList();

      if (patients.isEmpty && payments.isEmpty) {
        return SyncResult(
          success: true,
          message: 'No data to sync',
          syncLog: SyncLog(
            syncTime: DateTime.now(),
            recordsSynced: 0,
            status: 'completed',
          ),
        );
      }

      // Perform sync
      final result = await syncService.syncData(
        payments: payments,
        patients: patients,
        user: user,
      );

      if (result.success) {
        // Mark as synced in local DB
        await _markAsSynced(patients, payments);
        await _logSync(result.syncLog);
        await db.execute('COMMIT');
      } else {
        await db.execute('ROLLBACK');
      }

      return result;
    } catch (e) {
      await db.execute('ROLLBACK');
      return SyncResult(
        success: false,
        message: 'Sync failed: ${e.toString()}',
        syncLog: SyncLog(
          syncTime: DateTime.now(),
          recordsSynced: 0,
          status: 'failed',
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _markAsSynced(List<Patient> patients, List<Payment> payments) async {
    final db = await dbHelper.database;
    final batch = db.batch();

    // Mark patients as synced
    for (final patient in patients) {
      batch.update(
        'patients',
        {'isSynced': 1},
        where: 'patientNumber = ?',
        whereArgs: [patient.patientNumber],
      );
    }

    // Mark payments as synced
    for (final payment in payments) {
      batch.update(
        'payments',
        {'isSynced': 1},
        where: 'paymentId = ?',
        whereArgs: [payment.paymentId],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> _logSync(SyncLog syncLog) async {
    final db = await dbHelper.database;
    await db.insert('sync_logs', syncLog.toMap());
  }

  Future<List<SyncLog>> getSyncHistory() async {
    final db = await dbHelper.database;
    final maps = await db.query('sync_logs', orderBy: 'sync_time DESC');
    return maps.map((map) => SyncLog.fromMap(map)).toList();
  }
}