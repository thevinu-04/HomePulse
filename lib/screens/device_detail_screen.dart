import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';
import 'reports_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final _service = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Device?>(
      stream: _service.deviceStream(widget.deviceId),
      builder: (context, snapshot) {
        final device = snapshot.data;
        if (device == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(device.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart),
                tooltip: 'Usage report',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReportsScreen(device: device)),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildBody(device),
          ),
        );
      },
    );
  }

  Widget _buildBody(Device device) {
    switch (device.type) {
      case DeviceType.multiSwitch:
        return _multiSwitchView(device);
      case DeviceType.camera:
        return _cameraView(device);
      case DeviceType.safetyCritical:
        return _safetyView(device);
      case DeviceType.scheduledLight:
        return _scheduledView(device);
      case DeviceType.outlet:
        return _simpleToggleView(device);
    }
  }

  Widget _statusChip(DeviceStatus status) {
    final colors = {
      DeviceStatus.on: Colors.green,
      DeviceStatus.off: Colors.grey,
      DeviceStatus.error: Colors.red,
      DeviceStatus.disconnected: Colors.orange,
    };
    return Chip(
      label: Text(status.name.toUpperCase()),
      backgroundColor: colors[status]!.withOpacity(0.15),
      labelStyle: TextStyle(color: colors[status], fontWeight: FontWeight.bold),
    );
  }

  Widget _simpleToggleView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip(device.status),
        const SizedBox(height: 24),
        Center(
          child: Switch(
            value: device.status == DeviceStatus.on,
            onChanged: (_) => _service.toggleDevice(device),
          ),
        ),
      ],
    );
  }

  Widget _safetyView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip(device.status),
        const SizedBox(height: 12),
        Text('Max continuous ON: ${device.maxOnDurationSeconds ?? 0}s'),
        const SizedBox(height: 4),
        const Text(
          'This device is monitored server-side. If left ON past its max '
          'duration it will be auto-switched OFF and an alert raised.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Center(
          child: Switch(
            activeColor: Colors.red,
            value: device.status == DeviceStatus.on,
            onChanged: (_) => _service.toggleDevice(device),
          ),
        ),
      ],
    );
  }

  Widget _scheduledView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip(device.status),
        const SizedBox(height: 12),
        Text('Auto ON: ${device.scheduleStart ?? '--'}'),
        Text('Auto OFF: ${device.scheduleEnd ?? '--'}'),
        const SizedBox(height: 24),
        const Text('Manual override:'),
        Center(
          child: Switch(
            value: device.status == DeviceStatus.on,
            onChanged: (_) => _service.toggleDevice(device),
          ),
        ),
      ],
    );
  }

  Widget _multiSwitchView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip(device.status),
        const SizedBox(height: 12),
        Text('${device.channels.length}-switch gang unit'),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: device.channels.length,
            itemBuilder: (context, i) {
              final ch = device.channels[i];
              return Card(
                child: SwitchListTile(
                  title: Text(ch.label),
                  value: ch.isOn,
                  onChanged: (_) => _service.toggleChannel(device, ch.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cameraView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip(device.status),
        const SizedBox(height: 12),
        Text('Stream: ${device.streamUri ?? 'not configured'}'),
        const SizedBox(height: 16),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.videocam_outlined, color: Colors.white54, size: 48),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mock snapshot placeholder - wire up an actual image/network stream URI here.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
