import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';
import 'add_device_screen.dart';
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
              PopupMenuButton<String>(
                tooltip: 'Device actions',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddDeviceScreen(
                          floorId: device.floorId,
                          gridRow: device.gridRow,
                          gridCol: device.gridCol,
                          device: device,
                          service: _service,
                        ),
                      ),
                    );
                    return;
                  }

                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete device?'),
                        content: Text('Remove ${device.name} from this floor?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _service.deleteDevice(device.id);
                      if (mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _deviceHeader(device),
                const SizedBox(height: 20),
                Expanded(child: _buildBody(device)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _deviceHeader(Device device) {
    final showToggle = switch (device.type) {
      DeviceType.outlet || DeviceType.safetyCritical || DeviceType.scheduledLight => true,
      _ => false,
    };

    return Row(
      children: [
        Expanded(
          child: Text(
            device.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (showToggle)
          Switch(
            value: device.status == DeviceStatus.on,
            onChanged: (_) => _service.toggleDevice(device),
          ),
      ],
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

  Widget _simpleToggleView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Device is ${device.status.name.toUpperCase()}'),
      ],
    );
  }

  Widget _safetyView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Max continuous ON: ${device.maxOnDurationSeconds ?? 0}s'),
        const SizedBox(height: 4),
        const Text(
          'This device is monitored server-side. If left ON past its max '
          'duration it will be auto-switched OFF and an alert raised.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _scheduledView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Auto ON: ${device.scheduleStart ?? '--'}'),
        Text('Auto OFF: ${device.scheduleEnd ?? '--'}'),
        const SizedBox(height: 12),
        const Text('Manual override is controlled from the toggle above.'),
      ],
    );
  }

  Widget _multiSwitchView(Device device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
