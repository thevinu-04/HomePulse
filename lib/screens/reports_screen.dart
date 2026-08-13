import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, this.device});

  final Device? device;

  @override
  Widget build(BuildContext context) {
    if (device == null) {
      return const _HomeReportsScreen();
    }
    return _DeviceUsageReport(device: device!);
  }
}

class _DeviceUsageReport extends StatelessWidget {
  const _DeviceUsageReport({required this.device});

  final Device device;

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
            ..sort(
              (a, b) => (a.value['endedAt'] as int).compareTo(
                b.value['endedAt'] as int,
              ),
            );

          final totalMinutes = entries.fold<double>(
            0,
            (sum, entry) =>
                sum + ((entry.value['durationSeconds'] as num? ?? 0) / 60),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Total usage: ${totalMinutes.toStringAsFixed(1)} minutes across ${entries.length} sessions',
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
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY:
                                    (entries[i].value['durationSeconds']
                                            as num? ??
                                        0) /
                                    60,
                                width: 12,
                              ),
                            ],
                          ),
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
                    final ended = DateTime.fromMillisecondsSinceEpoch(
                      e.value['endedAt'] as int,
                    );
                    final dur = e.value['durationSeconds'] as num? ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        '${(dur / 60).toStringAsFixed(1)} min session',
                      ),
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

class _HomeReportsScreen extends StatelessWidget {
  const _HomeReportsScreen();

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _ReportsNav(onHomeTap: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<List<Device>>(
        stream: service.devicesStream(),
        builder: (context, deviceSnapshot) =>
            StreamBuilder<Map<String, dynamic>>(
              stream: service.usageLogsStream(),
              builder: (context, usageSnapshot) {
                if (deviceSnapshot.connectionState == ConnectionState.waiting ||
                    usageSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return _ReportsBody(
                  devices: deviceSnapshot.data ?? const <Device>[],
                  usage: usageSnapshot.data ?? const <String, dynamic>{},
                );
              },
            ),
      ),
    );
  }
}

class _ReportsNav extends StatelessWidget {
  const _ReportsNav({required this.onHomeTap});

  final VoidCallback onHomeTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: _ReportsNavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: onHomeTap,
          ),
        ),
        const Expanded(
          child: _ReportsNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            selected: true,
          ),
        ),
      ],
    ),
  );
}

class _ReportsNavItem extends StatelessWidget {
  const _ReportsNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.devices, required this.usage});

  final List<Device> devices;
  final Map<String, dynamic> usage;

  @override
  Widget build(BuildContext context) {
    final minutesByDevice = <String, double>{};
    var sessionCount = 0;
    for (final entry in usage.entries) {
      final logs = entry.value as Map<dynamic, dynamic>? ?? {};
      for (final log in logs.values) {
        final values = log as Map<dynamic, dynamic>;
        minutesByDevice[entry.key] =
            (minutesByDevice[entry.key] ?? 0) +
            ((values['durationSeconds'] as num? ?? 0) / 60);
        sessionCount++;
      }
    }
    final totalMinutes = minutesByDevice.values.fold<double>(
      0,
      (total, minutes) => total + minutes,
    );
    final analysedDevices = [...devices]
      ..sort(
        (first, second) => (minutesByDevice[second.id] ?? 0).compareTo(
          minutesByDevice[first.id] ?? 0,
        ),
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'Usage statistics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text('Tracked usage from your connected devices'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ReportMetric(
                icon: Icons.timer_outlined,
                label: 'Total usage',
                value: _formatDuration(totalMinutes),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReportMetric(
                icon: Icons.history_rounded,
                label: 'Sessions',
                value: '$sessionCount',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReportMetric(
                icon: Icons.power_settings_new_rounded,
                label: 'Active now',
                value:
                    '${devices.where((d) => d.status == DeviceStatus.on).length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Device analytics',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (devices.isEmpty)
          const _EmptyReportSection(message: 'No devices have been added yet.')
        else
          ...analysedDevices.map(
            (device) => _ActivityTile(
              device: device,
              minutes: minutesByDevice[device.id] ?? 0,
              sessions:
                  (usage[device.id] as Map<dynamic, dynamic>?)?.length ?? 0,
            ),
          ),
      ],
    );
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) return '${minutes.toStringAsFixed(1)} min';
    return '${(minutes / 60).toStringAsFixed(1)} hr';
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    height: 106,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.device,
    required this.sessions,
    required this.minutes,
  });

  final Device device;
  final int sessions;
  final double minutes;

  @override
  Widget build(BuildContext context) {
    final active = device.status == DeviceStatus.on;
    final status = active ? 'On now' : device.status.name.toUpperCase();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        active ? Icons.power_settings_new_rounded : Icons.power_outlined,
        color: active ? Colors.teal : Theme.of(context).colorScheme.outline,
      ),
      title: Text(device.name),
      subtitle: Text(
        '${minutes.toStringAsFixed(1)} min | $sessions ${sessions == 1 ? 'session' : 'sessions'} | ${_deviceType(device.type)}',
      ),
      trailing: Text(
        status,
        style: TextStyle(
          color: active ? Colors.teal : Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyReportSection extends StatelessWidget {
  const _EmptyReportSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message),
  );
}

String _deviceType(DeviceType type) => switch (type) {
  DeviceType.outlet => 'Outlet',
  DeviceType.multiSwitch => 'Multi-switch',
  DeviceType.safetyCritical => 'Safety-critical',
  DeviceType.scheduledLight => 'Scheduled light',
  DeviceType.camera => 'Camera',
};
