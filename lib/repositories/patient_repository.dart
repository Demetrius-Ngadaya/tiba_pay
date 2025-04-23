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
    );

    return await db.insert('patients', patientWithNumber.toMap());
  }

  Future<List<Patient>> getAllPatients() async {
    final db = await dbHelper.database;
    final maps = await db.query('patients', orderBy: 'patient_id DESC');
    return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
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

  Future<List<Patient>> searchPatients(String query) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'patients',
      where: 'firstName LIKE ? OR lastName LIKE ? OR patientNumber LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
  }
}