import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device.dart';
import '../models/floor.dart';
import '../services/firebase_service.dart';
import 'add_floor_screen.dart';
import 'alerts_screen.dart';
import 'device_detail_screen.dart';
import 'device_status_list_screen.dart';
import 'floor_grid_screen.dart';
import 'my_floors_screen.dart';
import 'reports_screen.dart';

class FloorListScreen extends StatefulWidget {
  const FloorListScreen({
    super.key,
    FirebaseService? service,
    this.isDark = false,
    this.onToggleTheme,
  }) : _service = service;

  final FirebaseService? _service;
  final bool isDark;
  final VoidCallback? onToggleTheme;

  FirebaseService get service => _service ?? FirebaseService();

  @override
  State<FloorListScreen> createState() => _FloorListScreenState();
}

class _FloorListScreenState extends State<FloorListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomePulse',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: widget.isDark ? 'Use light mode' : 'Use night mode',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Safety alerts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _DashboardNav(
          onReportsTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          ),
        ),
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
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.service,
    required this.floors,
    required this.devices,
  });

  final FirebaseService service;
  final List<Floor> floors;
  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    final onlineDevices = devices
        .where(
          (device) =>
              device.status != DeviceStatus.disconnected &&
              device.status != DeviceStatus.error,
        )
        .length;
    final activeDevices = devices
        .where((device) => device.status == DeviceStatus.on)
        .length;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.alertsStream(),
      builder: (context, alertSnapshot) {
        final alertCount = alertSnapshot.data?.length ?? 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
          children: [
            const _DashboardHero(),
            const SizedBox(height: 18),
            _MetricsRow(
              online: onlineDevices,
              active: activeDevices,
              alerts: alertCount,
              onOnlineTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceStatusListScreen(
                    filter: DeviceStatusFilter.online,
                    service: service,
                  ),
                ),
              ),
              onActiveTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceStatusListScreen(
                    filter: DeviceStatusFilter.on,
                    service: service,
                  ),
                ),
              ),
              onAlertsTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
              ),
            ),
            const SizedBox(height: 20),
            if (floors.isEmpty)
              _EmptyFloors(
                onAddFloor: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddFloorScreen(service: service),
                  ),
                ),
              )
            else
              _DashboardFloorPreview(
                floors: floors,
                devices: devices,
                service: service,
              ),
          ],
        );
      },
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 126,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -4,
            width: 175,
            child: Opacity(
              opacity: 0.86,
              child: Image.asset('assets/floorplans/dashboard_house.jpg'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Home',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Realtime monitoring & control',
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.online,
    required this.active,
    required this.alerts,
    required this.onOnlineTap,
    required this.onActiveTap,
    required this.onAlertsTap,
  });

  final int online;
  final int active;
  final int alerts;
  final VoidCallback onOnlineTap;
  final VoidCallback onActiveTap;
  final VoidCallback onAlertsTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _MetricTile(
          label: 'Online',
          value: online,
          icon: Icons.wifi_rounded,
          onTap: onOnlineTap,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _MetricTile(
          label: 'On',
          value: active,
          icon: Icons.power_settings_new_rounded,
          onTap: onActiveTap,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _MetricTile(
          label: 'Alerts',
          value: alerts,
          icon: alerts == 0
              ? Icons.verified_outlined
              : Icons.warning_amber_rounded,
          isAlert: alerts > 0,
          onTap: onAlertsTap,
        ),
      ),
    ],
  );
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
    final color = isAlert
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 96,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardFloorPreview extends StatefulWidget {
  const _DashboardFloorPreview({
    required this.floors,
    required this.devices,
    required this.service,
  });

  final List<Floor> floors;
  final List<Device> devices;
  final FirebaseService service;

  @override
  State<_DashboardFloorPreview> createState() => _DashboardFloorPreviewState();
}

class _DashboardFloorPreviewState extends State<_DashboardFloorPreview> {
  String? _selectedFloorId;

  @override
  Widget build(BuildContext context) {
    final floors = [...widget.floors]
      ..sort(
        (first, second) =>
            _floorRank(first.name).compareTo(_floorRank(second.name)),
      );
    final selectedFloor = floors.firstWhere(
      (floor) => floor.id == _selectedFloorId,
      orElse: () => floors.first,
    );
    final floorDevices = widget.devices
        .where((device) => device.floorId == selectedFloor.id)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F0C1D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Floors',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text('Select a floor to inspect devices'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Manage floors',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyFloorsScreen(service: widget.service),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: floors.map((floor) {
                final selected = floor.id == selectedFloor.id;
                return ChoiceChip(
                  label: Text(floor.name),
                  avatar: Icon(
                    selected ? Icons.home_rounded : Icons.layers_outlined,
                    size: 16,
                  ),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedFloorId = floor.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              'Devices on ${selectedFloor.name}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (floorDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No devices on this floor yet.')),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 290,
                  mainAxisExtent: 104,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: floorDevices.length,
                itemBuilder: (context, index) => _DashboardDeviceCard(
                  device: floorDevices[index],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DeviceDetailScreen(deviceId: floorDevices[index].id),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FloorGridScreen(floor: selectedFloor),
                  ),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _floorRank(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('ground')) return 0;
    if (normalized.contains('first') || normalized.contains('1st')) return 1;
    if (normalized.contains('second') || normalized.contains('2nd')) return 2;
    if (normalized.contains('third') || normalized.contains('3rd')) return 3;
    return 100;
  }
}

class _DashboardDeviceCard extends StatelessWidget {
  const _DashboardDeviceCard({required this.device, required this.onTap});

  final Device device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_deviceIcon(device.type), size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(_deviceTypeLabel(device.type)),
            const SizedBox(height: 4),
            Text(
              device.status.name.toUpperCase(),
              style: TextStyle(
                color: device.status == DeviceStatus.on
                    ? Colors.teal
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardNav extends StatelessWidget {
  const _DashboardNav({required this.onReportsTap});
  final VoidCallback onReportsTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Expanded(
          child: _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: true,
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            onTap: onReportsTap,
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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

IconData _deviceIcon(DeviceType type) => switch (type) {
  DeviceType.outlet => Icons.power_outlined,
  DeviceType.safetyCritical => Icons.iron_outlined,
  DeviceType.scheduledLight => Icons.lightbulb_outline,
  DeviceType.multiSwitch => Icons.tune_outlined,
  DeviceType.camera => Icons.videocam_outlined,
};

String _deviceTypeLabel(DeviceType type) => switch (type) {
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
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 14),
          Expanded(child: Text(message)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}
