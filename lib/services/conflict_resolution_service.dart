import 'package:tiba_pay/utils/database_helper.dart';
import 'package:tiba_pay/services/sync_service.dart';
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/models/payment.dart';
import 'package:tiba_pay/models/sync_conflict.dart';

class ConflictResolutionService {
  final DatabaseHelper dbHelper;
  final SyncService syncService;

  ConflictResolutionService({
    required this.dbHelper,
    required this.syncService,
  });

  Future<List<SyncConflict>> checkConflicts(List<Patient> patients, List<Payment> payments) async {
    final db = await dbHelper.database;
    final conflicts = <SyncConflict>[];

    // Check patient conflicts
    for (final patient in patients) {
      final existing = await db.query(
        'patients',
        where: 'patientNumber = ? AND isSynced = ?',
        whereArgs: [patient.patientNumber, 1],
      );

      if (existing.isNotEmpty) {
        final serverPatient = Patient.fromMap(existing.first);
        if (patient.createdAt.isAfter(serverPatient.createdAt)) {
          conflicts.add(SyncConflict(
            type: 'patient',
            id: patient.patientNumber,
            localValue: patient.toMap(),
            serverValue: serverPatient.toMap(),
            description: 'Patient ${patient.fullName} has conflicting data',
          ));
        }
      }
    }

    // Check payment conflicts
    for (final payment in payments) {
      final existing = await db.query(
        'payments',
        where: 'paymentId = ? AND isSynced = ?',
        whereArgs: [payment.paymentId, 1],
      );

      if (existing.isNotEmpty) {
        final serverPayment = Payment.fromMap(existing.first);
        if (payment.paymentDate.isAfter(serverPayment.paymentDate)) {
          conflicts.add(SyncConflict(
            type: 'payment',
            id: payment.paymentId,
            localValue: payment.toMap(),
            serverValue: serverPayment.toMap(),
            description: 'Payment ${payment.paymentId} has conflicting data',
          ));
        }
      }
    }

    return conflicts;
  }

  Future<void> resolveConflict(SyncConflict conflict, String resolution) async {
    final db = await dbHelper.database;
    
    switch (resolution) {
      case 'keep_local':
        if (conflict.type == 'patient') {
          await db.update(
            'patients',
            conflict.localValue,
            where: 'patientNumber = ?',
            whereArgs: [conflict.id],
          );
        } else {
          await db.update(
            'payments',
            conflict.localValue,
            where: 'paymentId = ?',
            whereArgs: [conflict.id],
          );
        }
        break;
      
      case 'keep_server':
        if (conflict.type == 'patient') {
          await db.update(
            'patients',
            conflict.serverValue,
            where: 'patientNumber = ?',
            whereArgs: [conflict.id],
          );
        } else {
          await db.update(
            'payments',
            conflict.serverValue,
            where: 'paymentId = ?',
            whereArgs: [conflict.id],
          );
        }
        break;
      
      case 'merge':
        final merged = _mergeData(conflict);
        if (conflict.type == 'patient') {
          await db.update(
            'patients',
            merged,
            where: 'patientNumber = ?',
            whereArgs: [conflict.id],
          );
        } else {
          await db.update(
            'payments',
            merged,
            where: 'paymentId = ?',
            whereArgs: [conflict.id],
          );
        }
        break;
    }
  }

  Map<String, dynamic> _mergeData(SyncConflict conflict) {
    final local = conflict.localValue;
    final server = conflict.serverValue;
    
    return {
      ...server,
      ...local,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}