import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all alerts',
            onPressed: () => _confirmClearAll(context, service),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.alertsStream(),
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return const Center(
              child: Text('No alerts. All safety-critical devices nominal.'),
            );
          }
          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, i) {
              final a = alerts[i];
              final ts = DateTime.fromMillisecondsSinceEpoch(
                a['timestamp'] ?? 0,
              );
              return ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
                title: Text(_alertTitle(a)),
                subtitle: Text(
                  '${_alertLocation(a)}\n${DateFormat('MMM d, HH:mm:ss').format(ts)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear alert',
                  onPressed: () => service.clearAlert(a['id'] as String),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _alertTitle(Map<String, dynamic> alert) {
    final deviceName = alert['deviceName'];
    final status = alert['status'];
    if (deviceName != null && status != null) {
      return '$deviceName is $status.';
    }
    return alert['message'] ?? 'Auto shut-off triggered';
  }

  String _alertLocation(Map<String, dynamic> alert) {
    final floorName = alert['floorName'];
    return floorName == null ? 'Floor not recorded' : 'Floor: $floorName';
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    FirebaseService service,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all alerts?'),
        content: const Text('This permanently removes every alert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await service.clearAllAlerts();
    }
  }
}
