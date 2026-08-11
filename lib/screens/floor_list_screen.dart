import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device.dart';
import '../models/floor.dart';
import '../services/firebase_service.dart';
import 'add_floor_screen.dart';
import 'device_detail_screen.dart';
import 'floor_grid_screen.dart';
import 'alerts_screen.dart';

class FloorListScreen extends StatefulWidget {
  const FloorListScreen({super.key, FirebaseService? service})
      : _service = service;

  final FirebaseService? _service;

  FirebaseService get service => _service ?? FirebaseService();

  @override
  State<FloorListScreen> createState() => _FloorListScreenState();
}

class _FloorListScreenState extends State<FloorListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomePulse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Safety alerts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Device>>(
        stream: widget.service.devicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final devices = snapshot.data ?? <Device>[];
          return StreamBuilder<List<Floor>>(
            stream: widget.service.floorsStream(),
            builder: (context, floorSnapshot) {
              if (floorSnapshot.connectionState == ConnectionState.waiting &&
                  !floorSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _DashboardBody(
                service: widget.service,
                floors: floorSnapshot.data ?? <Floor>[],
                devices: devices,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Floor'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddFloorScreen(service: widget.service)),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({
    required this.service,
    required this.floors,
    required this.devices,
  });

  final FirebaseService service;
  final List<Floor> floors;
  final List<Device> devices;

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  String? _selectedFloorId;

  @override
  Widget build(BuildContext context) {
    final selectedFloor = _resolveSelectedFloor();
    final selectedDevices = selectedFloor == null
        ? <Device>[]
        : widget.devices
            .where((device) => device.floorId == selectedFloor.id)
            .toList();
    final onlineDevices = widget.devices
        .where((device) =>
            device.status != DeviceStatus.disconnected &&
            device.status != DeviceStatus.error)
        .length;
    final activeDevices = widget.devices
        .where((device) => device.status == DeviceStatus.on)
        .length;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.service.alertsStream(),
      builder: (context, alertSnapshot) {
        final alertCount = alertSnapshot.data?.length ?? 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
          children: [
            const _DashboardTitle(),
            const SizedBox(height: 16),
            _MetricsRow(
              online: onlineDevices,
              active: activeDevices,
              alerts: alertCount,
              onAlertsTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen())),
            ),
            const SizedBox(height: 16),
            if (widget.floors.isEmpty)
              _EmptyFloors(
                onAddFloor: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddFloorScreen(service: widget.service)),
                ),
              )
            else
              _FloorMonitor(
                floors: widget.floors,
                selectedFloor: selectedFloor!,
                devices: selectedDevices,
                onFloorChanged: (floorId) => setState(() {
                  _selectedFloorId = floorId;
                }),
                onFloorTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FloorGridScreen(floor: selectedFloor)),
                ),
                onDeviceTap: _openDevice,
              ),
          ],
        );
      },
    );
  }

  Floor? _resolveSelectedFloor() {
    if (widget.floors.isEmpty) {
      return null;
    }
    return widget.floors.firstWhere(
      (floor) => floor.id == _selectedFloorId,
      orElse: () => widget.floors.first,
    );
  }

  void _openDevice(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceDetailScreen(deviceId: device.id)),
    );
  }
}

class _DashboardTitle extends StatelessWidget {
  const _DashboardTitle();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Home', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('Realtime monitoring & control'),
        ],
      );
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.online,
    required this.active,
    required this.alerts,
    required this.onAlertsTap,
  });

  final int online;
  final int active;
  final int alerts;
  final VoidCallback onAlertsTap;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _MetricTile(label: 'Online', value: online, icon: Icons.wifi_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _MetricTile(label: 'On', value: active, icon: Icons.power_settings_new_rounded)),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Alerts',
            value: alerts,
            icon: alerts == 0 ? Icons.verified_outlined : Icons.warning_amber_rounded,
            isAlert: alerts > 0,
            onTap: onAlertsTap,
          ),
        ),
      ]);
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.isAlert = false,
    this.onTap,
  });
  final String label;
  final int value;
  final IconData icon;
  final bool isAlert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isAlert ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(label),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FloorMonitor extends StatelessWidget {
  const _FloorMonitor({
    required this.floors,
    required this.selectedFloor,
    required this.devices,
    required this.onFloorChanged,
    required this.onFloorTap,
    required this.onDeviceTap,
  });

  final List<Floor> floors;
  final Floor selectedFloor;
  final List<Device> devices;
  final ValueChanged<String> onFloorChanged;
  final VoidCallback onFloorTap;
  final ValueChanged<Device> onDeviceTap;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Floors', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Select a floor to inspect devices.'),
                ]),
              ),
              DropdownButton<String>(
                value: selectedFloor.id,
                underline: const SizedBox.shrink(),
                items: floors
                    .map((floor) => DropdownMenuItem(
                        value: floor.id, child: Text(floor.name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onFloorChanged(value);
                },
              ),
            ]),
            const SizedBox(height: 12),
            InkWell(
              onTap: onFloorTap,
              borderRadius: BorderRadius.circular(8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 290,
                  mainAxisExtent: 112,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: devices.length,
                itemBuilder: (context, index) => _MonitorDeviceCard(
                  device: devices[index],
                  onTap: () => onDeviceTap(devices[index]),
                ),
              ),
            ),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No devices on this floor yet.')),
              ),
          ]),
        ),
      );
}

class _MonitorDeviceCard extends StatelessWidget {
  const _MonitorDeviceCard({required this.device, required this.onTap});
  final Device device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_deviceIcon(device.type), size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(device.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
              const Spacer(),
              Text(_typeLabel(device.type)),
              const SizedBox(height: 4),
              Text(device.status.name.toUpperCase(),
                  style: TextStyle(
                    color: device.status == DeviceStatus.on
                        ? Colors.teal
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  )),
            ]),
          ),
        ),
      );
}

IconData _deviceIcon(DeviceType type) => switch (type) {
      DeviceType.outlet => Icons.power_outlined,
      DeviceType.safetyCritical => Icons.iron_outlined,
      DeviceType.scheduledLight => Icons.lightbulb_outline,
      DeviceType.multiSwitch => Icons.tune_outlined,
      DeviceType.camera => Icons.videocam_outlined,
    };

String _typeLabel(DeviceType type) => switch (type) {
      DeviceType.outlet => 'OUTLET',
      DeviceType.safetyCritical => 'SAFETY OUTLET',
      DeviceType.scheduledLight => 'LIGHT',
      DeviceType.multiSwitch => 'MULTI-SWITCH',
      DeviceType.camera => 'CAMERA',
    };

class _EmptyFloors extends StatelessWidget {
  const _EmptyFloors({required this.onAddFloor});
  final VoidCallback onAddFloor;

  @override
  Widget build(BuildContext context) => _EmptyMessage(
        icon: Icons.layers_clear_outlined,
        message: 'Create your first floor to start placing devices.',
        actionLabel: 'Add floor',
        onAction: onAddFloor,
      );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(child: Text(message)),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ]),
        ),
      );
}
