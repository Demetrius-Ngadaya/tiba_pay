class SyncConflict {
  final String type; // 'patient' or 'payment'
  final String id;
  final Map<String, dynamic> localValue;
  final Map<String, dynamic> serverValue;
  final String description;

  SyncConflict({
    required this.type,
    required this.id,
    required this.localValue,
    required this.serverValue,
    required this.description,
  });
}