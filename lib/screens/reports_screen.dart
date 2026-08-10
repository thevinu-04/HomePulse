import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';

class ReportsScreen extends StatelessWidget {
  final Device device;
  const ReportsScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return Scaffold(
      appBar: AppBar(title: Text('${device.name} - Usage')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: service.usageLogsForDevice(device.id),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? {};
          if (logs.isEmpty) {
            return const Center(child: Text('No usage recorded yet.'));
          }

          final entries = logs.entries.toList()
            ..sort((a, b) =>
                (a.value['endedAt'] as int).compareTo(b.value['endedAt'] as int));

          final totalMinutes =
              entries.fold<int>(0, (sum, e) => sum + ((e.value['durationSeconds'] as int) ~/ 60));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Total usage: $totalMinutes minutes across ${entries.length} sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 220,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BarChart(
                    BarChartData(
                      barGroups: [
                        for (int i = 0; i < entries.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: (entries[i].value['durationSeconds'] as int) / 60.0,
                              width: 12,
                            ),
                          ]),
                      ],
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[entries.length - 1 - i];
                    final ended = DateTime.fromMillisecondsSinceEpoch(e.value['endedAt']);
                    final dur = e.value['durationSeconds'] as int;
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text('${(dur / 60).toStringAsFixed(1)} min session'),
                      subtitle: Text(DateFormat('MMM d, HH:mm').format(ended)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
