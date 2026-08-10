import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Alerts')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.alertsStream(),
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return const Center(child: Text('No alerts. All safety-critical devices nominal.'));
          }
          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, i) {
              final a = alerts[i];
              final ts = DateTime.fromMillisecondsSinceEpoch(a['timestamp'] ?? 0);
              return ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                title: Text(a['message'] ?? 'Auto shut-off triggered'),
                subtitle: Text(DateFormat('MMM d, HH:mm:ss').format(ts)),
              );
            },
          );
        },
      ),
    );
  }
}
