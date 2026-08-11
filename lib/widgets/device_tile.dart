import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceTile extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const DeviceTile({super.key, required this.device, required this.onTap});

  Color _statusColor() {
    switch (device.status) {
      case DeviceStatus.on:
        return Colors.green;
      case DeviceStatus.off:
        return Colors.grey;
      case DeviceStatus.error:
        return Colors.red;
      case DeviceStatus.disconnected:
        return Colors.orange;
    }
  }

  IconData _typeIcon() {
    switch (device.type) {
      case DeviceType.outlet:
        return Icons.power;
      case DeviceType.multiSwitch:
        return Icons.dashboard_customize;
      case DeviceType.safetyCritical:
        return Icons.iron;
      case DeviceType.scheduledLight:
        return Icons.lightbulb;
      case DeviceType.camera:
        return Icons.videocam;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_typeIcon(), color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                device.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9),
              ),
              Text(
                device.status.name.toUpperCase(),
                style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
