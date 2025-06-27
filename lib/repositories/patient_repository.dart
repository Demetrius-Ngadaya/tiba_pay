import 'package:sqflite/sqflite.dart';
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/utils/database_helper.dart';

class PatientRepository {
  final DatabaseHelper dbHelper;

  PatientRepository({required this.dbHelper});

  Future<String> _generatePatientNumber() async {
    final db = await dbHelper.database;
    final lastPatient = await db.query(
      'patients',
      orderBy: 'patient_id DESC',
      limit: 1,
    );

    if (lastPatient.isEmpty) {
      return 'A-0001';
    }

    final lastNumber = lastPatient.first['patientNumber'] as String;
    final numberPart = int.parse(lastNumber.split('-')[1]);
    return 'A-${(numberPart + 1).toString().padLeft(4, '0')}';
  }

  Future<int> createPatient(Patient patient) async {
    final db = await dbHelper.database;
    final patientWithNumber = Patient(
      patientNumber: patient.patientNumber.isEmpty 
          ? await _generatePatientNumber() 
          : patient.patientNumber,
      firstName: patient.firstName,
      middleName: patient.middleName,
      lastName: patient.lastName,
      sponsor: patient.sponsor,
      phoneNumber: patient.phoneNumber,
      address: patient.address,
      createdAt: patient.createdAt,
      createdBy: patient.createdBy,
      isSynced: patient.isSynced,  
    );

    return await db.insert('patients', patientWithNumber.toMap());
  }

  Future<List<Patient>> getAllPatients({
    int? limit,
    int? offset,
    String? searchQuery,
    String? patientNumber,
    String? patientName,
    String? sponsor,
    int? createdBy,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = '1 = 1';
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += '''
        AND (patientNumber LIKE ? 
        OR firstName LIKE ? 
        OR lastName LIKE ? 
        OR sponsor LIKE ? 
        OR phoneNumber LIKE ?)
      ''';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll([searchTerm, searchTerm, searchTerm, searchTerm, searchTerm]);
    }

    if (patientNumber != null && patientNumber.isNotEmpty) {
      where += ' AND patientNumber LIKE ?';
      whereArgs.add('%$patientNumber%');
    }

    if (patientName != null && patientName.isNotEmpty) {
      where += ' AND (firstName LIKE ? OR lastName LIKE ?)';
      whereArgs.addAll(['%$patientName%', '%$patientName%']);
    }

    if (sponsor != null && sponsor.isNotEmpty) {
      where += ' AND sponsor LIKE ?';
      whereArgs.add('%$sponsor%');
    }

    if (createdBy != null) {
      where += ' AND createdBy = ?';
      whereArgs.add(createdBy);
    }

    if (startDate != null) {
      where += ' AND createdAt >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND createdAt <= ?';
      whereArgs.add(endDate.add(const Duration(days: 1)).millisecondsSinceEpoch);
    }

    final maps = await db.query(
      'patients',
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'patient_id DESC',
    );
    
    return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
  }

  Future<int> getPatientsCount({
    String? searchQuery,
    String? patientNumber,
    String? patientName,
    String? sponsor,
    int? createdBy,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await dbHelper.database;
    
    // Build where clause based on filters
    var where = '1 = 1';
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += '''
        AND (patientNumber LIKE ? 
        OR firstName LIKE ? 
        OR lastName LIKE ? 
        OR sponsor LIKE ? 
        OR phoneNumber LIKE ?)
      ''';
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll([searchTerm, searchTerm, searchTerm, searchTerm, searchTerm]);
    }

    if (patientNumber != null && patientNumber.isNotEmpty) {
      where += ' AND patientNumber LIKE ?';
      whereArgs.add('%$patientNumber%');
    }

    if (patientName != null && patientName.isNotEmpty) {
      where += ' AND (firstName LIKE ? OR lastName LIKE ?)';
      whereArgs.addAll(['%$patientName%', '%$patientName%']);
    }

    if (sponsor != null && sponsor.isNotEmpty) {
      where += ' AND sponsor LIKE ?';
      whereArgs.add('%$sponsor%');
    }

    if (createdBy != null) {
      where += ' AND createdBy = ?';
      whereArgs.add(createdBy);
    }

    if (startDate != null) {
      where += ' AND createdAt >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND createdAt <= ?';
      whereArgs.add(endDate.add(const Duration(days: 1)).millisecondsSinceEpoch);
    }

    final count = await db.rawQuery('SELECT COUNT(*) FROM patients WHERE $where', whereArgs);
    return Sqflite.firstIntValue(count) ?? 0;
  }

  Future<int> updatePatient(Patient patient) async {
    final db = await dbHelper.database;
    return await db.update(
      'patients',
      patient.toMap(),
      where: 'patientNumber = ?',
      whereArgs: [patient.patientNumber],
    );
  }

  Future<int> deletePatient(String patientNumber) async {
    final db = await dbHelper.database;
    return await db.delete(
      'patients',
      where: 'patientNumber = ?',
      whereArgs: [patientNumber],
    );
  }
}