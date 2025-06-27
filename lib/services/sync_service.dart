import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tiba_pay/models/payment.dart';
import 'package:tiba_pay/models/patient.dart';
import 'package:tiba_pay/models/user.dart';
import 'package:tiba_pay/models/sync_log.dart';

class SyncService {
  static const String _baseUrl = 'https://your-laravel-api.com/api';
  final String _authToken;
  final http.Client _client;

  SyncService(this._authToken, {http.Client? client}) 
    : _client = client ?? http.Client();

  Future<SyncResult> syncData({
    required List<Payment> payments,
    required List<Patient> patients,
    required User user,
  }) async {
    // Check connectivity first
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
        syncLog: SyncLog(
          syncTime: DateTime.now(),
          recordsSynced: 0,
          status: 'failed',
          error: 'No internet connection',
        ),
      );
    }

    try {
      // Prepare sync log
      final totalRecords = payments.length + patients.length;
      SyncLog syncLog = SyncLog(
        syncTime: DateTime.now(),
        recordsSynced: 0,
        status: 'in_progress',
      );

      // Sync Patients
      if (patients.isNotEmpty) {
        final patientResponse = await _client.post(
          Uri.parse('$_baseUrl/patients/batch'),
          headers: _buildHeaders(),
          body: jsonEncode({
            'patients': patients.map((p) => p.toApiMap()).toList(),
            'user_id': user.userId,
          }),
        );

        if (patientResponse.statusCode != 200) {
          throw SyncException(
            'Failed to sync patients: ${patientResponse.body}',
            statusCode: patientResponse.statusCode,
          );
        }

        syncLog = syncLog.copyWith(
          recordsSynced: syncLog.recordsSynced + patients.length,
        );
      }

      // Sync Payments
      if (payments.isNotEmpty) {
        final paymentResponse = await _client.post(
          Uri.parse('$_baseUrl/payments/batch'),
          headers: _buildHeaders(),
          body: jsonEncode({
            'payments': payments.map((p) => p.toApiMap()).toList(),
            'user_id': user.userId,
          }),
        );

        if (paymentResponse.statusCode != 200) {
          throw SyncException(
            'Failed to sync payments: ${paymentResponse.body}',
            statusCode: paymentResponse.statusCode,
          );
        }

        syncLog = syncLog.copyWith(
          recordsSynced: syncLog.recordsSynced + payments.length,
          status: 'completed',
        );
      } else {
        syncLog = syncLog.copyWith(
          status: 'completed',
        );
      }

      return SyncResult(
        success: true,
        message: 'Synced $totalRecords records successfully',
        syncLog: syncLog,
      );
    } on SyncException catch (e) {
      return SyncResult(
        success: false,
        message: e.message,
        syncLog: SyncLog(
          syncTime: DateTime.now(),
          recordsSynced: 0,
          status: 'failed',
          error: e.message,
        ),
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
        syncLog: SyncLog(
          syncTime: DateTime.now(),
          recordsSynced: 0,
          status: 'failed',
          error: e.toString(),
        ),
      );
    }
  }

  Map<String, String> _buildHeaders() {
    return {
      'Authorization': 'Bearer $_authToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Version': '1.0.0',
    };
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Authorization': 'Bearer $_authToken'},
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class SyncException implements Exception {
  final String message;
  final int? statusCode;

  SyncException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class SyncResult {
  final bool success;
  final String message;
  final SyncLog syncLog;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncLog,
  });
}