import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiba_pay/models/sync_log.dart';
import 'package:tiba_pay/repositories/sync_repository.dart';
import 'package:tiba_pay/services/sync_service.dart';
import 'package:tiba_pay/utils/database_helper.dart';
import 'package:tiba_pay/models/user.dart';

import '../repositories/sync_repository.dart';

class SyncStatusWidget extends StatefulWidget {
  final User user;

  const SyncStatusWidget({super.key, required this.user});

  @override
  _SyncStatusWidgetState createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  late SyncRepository _syncRepo;
  SyncLog? _lastSync;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _syncRepo = SyncRepository(
      dbHelper: DatabaseHelper.instance,
      syncService: SyncService(widget.user.authToken),
    );
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final history = await _syncRepo.getSyncHistory();
    if (history.isNotEmpty) {
      setState(() => _lastSync = history.first);
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    
    final result = await _syncRepo.syncUnsyncedData(widget.user);
    
    setState(() {
      _isSyncing = false;
      _lastSync = result.syncLog;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Sync',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_lastSync != null) ...[
              _buildSyncInfo('Last Sync', 
                DateFormat('yyyy-MM-dd HH:mm').format(_lastSync!.syncTime)),
              _buildSyncInfo('Records Synced', 
                _lastSync!.recordsSynced.toString()),
              _buildSyncInfo('Status', 
                _lastSync!.status.toUpperCase()),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncData,
              icon: _isSyncing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 20),
              label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}