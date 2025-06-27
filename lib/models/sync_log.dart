// lib/models/sync_log.dart
class SyncLog {
  final DateTime syncTime;
  final int recordsSynced;
  final String status; // 'pending', 'in_progress', 'completed', 'failed'
  final String? error;
  final String? deviceInfo;
  final String? appVersion;

  SyncLog({
    required this.syncTime,
    required this.recordsSynced,
    required this.status,
    this.error,
    this.deviceInfo,
    this.appVersion,
  });
 SyncLog copyWith({
  DateTime? syncTime,
  int? recordsSynced,
  String? status,
  String? error,
}) {
  return SyncLog(
    syncTime: syncTime ?? this.syncTime,
    recordsSynced: recordsSynced ?? this.recordsSynced,
    status: status ?? this.status,
    error: error ?? this.error,
  );
}
  // Add this factory constructor
  factory SyncLog.fromMap(Map<String, dynamic> map) {
    return SyncLog(
      syncTime: DateTime.parse(map['sync_time']),
      recordsSynced: map['records_synced'] ?? 0,
      status: map['status'] ?? 'pending',
      error: map['error'],
      deviceInfo: map['device_info'],
      appVersion: map['app_version'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sync_time': syncTime.toIso8601String(),
      'records_synced': recordsSynced,
      'status': status,
      'error': error,
      'device_info': deviceInfo,
      'app_version': appVersion,
    };
  }
}