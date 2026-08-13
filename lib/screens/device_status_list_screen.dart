import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/firebase_service.dart';
import 'device_detail_screen.dart';

enum DeviceStatusFilter { online, on }

class DeviceStatusListScreen extends StatelessWidget {
  const DeviceStatusListScreen({
    super.key,
    required this.filter,
    required this.service,
  });

  final DeviceStatusFilter filter;
  final FirebaseService service;

  @override
  Widget build(BuildContext context) {
    final isOnline = filter == DeviceStatusFilter.online;
    return Scaffold(
      appBar: AppBar(title: Text(isOnline ? 'Online Devices' : 'Devices On')),
      body: StreamBuilder<List<Device>>(
        stream: service.devicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final devices = (snapshot.data ?? <Device>[]).where((device) {
            if (isOnline) {
              return device.status != DeviceStatus.error &&
                  device.status != DeviceStatus.disconnected;
            }
            return device.status == DeviceStatus.on;
          }).toList();

          if (devices.isEmpty) {
            return Center(
              child: Text(
                isOnline ? 'No devices are online.' : 'No devices are on.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                child: ListTile(
                  leading: Icon(_deviceIcon(device.type)),
                  title: Text(device.name),
                  subtitle: Text(_deviceTypeLabel(device.type)),
                  trailing: Text(
                    device.status.name.toUpperCase(),
                    style: TextStyle(
                      color: device.status == DeviceStatus.on
                          ? Colors.teal
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeviceDetailScreen(deviceId: device.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _deviceIcon(DeviceType type) => switch (type) {
    DeviceType.outlet => Icons.power_outlined,
    DeviceType.multiSwitch => Icons.tune_outlined,
    DeviceType.safetyCritical => Icons.iron_outlined,
    DeviceType.scheduledLight => Icons.lightbulb_outline,
    DeviceType.camera => Icons.videocam_outlined,
  };

  String _deviceTypeLabel(DeviceType type) => switch (type) {
    DeviceType.outlet => 'OUTLET',
    DeviceType.multiSwitch => 'MULTI-SWITCH',
    DeviceType.safetyCritical => 'SAFETY OUTLET',
    DeviceType.scheduledLight => 'LIGHT',
    DeviceType.camera => 'CAMERA',
  };
}
