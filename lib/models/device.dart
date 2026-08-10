/// Every device type the app supports.
/// This single enum + a flexible config map is what lets one Firebase
/// node type represent outlets, multi-switch gangs, irons, scheduled
/// lights and cameras without five separate tables.
enum DeviceType { outlet, multiSwitch, safetyCritical, scheduledLight, camera }

enum DeviceStatus { on, off, error, disconnected }

DeviceType deviceTypeFromString(String s) =>
    DeviceType.values.firstWhere((e) => e.name == s, orElse: () => DeviceType.outlet);

DeviceStatus deviceStatusFromString(String s) =>
    DeviceStatus.values.firstWhere((e) => e.name == s, orElse: () => DeviceStatus.disconnected);

class SwitchChannel {
  final String id;
  final String label;
  final bool isOn;

  SwitchChannel({required this.id, required this.label, required this.isOn});

  factory SwitchChannel.fromMap(String id, Map<dynamic, dynamic> map) {
    return SwitchChannel(
      id: id,
      label: map['label'] ?? id,
      isOn: map['isOn'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'isOn': isOn};

  SwitchChannel copyWith({bool? isOn}) =>
      SwitchChannel(id: id, label: label, isOn: isOn ?? this.isOn);
}

class Device {
  final String id;
  final String floorId;
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final int gridRow;
  final int gridCol;

  // Turned on at (epoch millis) - used for safety-cutoff + schedules + usage logs
  final int? turnedOnAt;

  // safetyCritical only: max allowed continuous ON duration, in seconds
  final int? maxOnDurationSeconds;

  // scheduledLight only: preset auto on/off window, "HH:mm" 24h format
  final String? scheduleStart;
  final String? scheduleEnd;

  // multiSwitch only: independently addressable channels within one unit
  final List<SwitchChannel> channels;

  // camera only: mock snapshot/stream uri
  final String? streamUri;

  // total accumulated ON seconds, for reporting
  final int totalOnSeconds;

  Device({
    required this.id,
    required this.floorId,
    required this.name,
    required this.type,
    required this.status,
    required this.gridRow,
    required this.gridCol,
    this.turnedOnAt,
    this.maxOnDurationSeconds,
    this.scheduleStart,
    this.scheduleEnd,
    this.channels = const [],
    this.streamUri,
    this.totalOnSeconds = 0,
  });

  factory Device.fromMap(String id, Map<dynamic, dynamic> map) {
    final channelsMap = map['channels'] as Map<dynamic, dynamic>? ?? {};
    return Device(
      id: id,
      floorId: map['floorId'] ?? '',
      name: map['name'] ?? 'Unnamed device',
      type: deviceTypeFromString(map['type'] ?? 'outlet'),
      status: deviceStatusFromString(map['status'] ?? 'disconnected'),
      gridRow: map['gridRow'] ?? 0,
      gridCol: map['gridCol'] ?? 0,
      turnedOnAt: map['turnedOnAt'],
      maxOnDurationSeconds: map['maxOnDurationSeconds'],
      scheduleStart: map['scheduleStart'],
      scheduleEnd: map['scheduleEnd'],
      channels: channelsMap.entries
          .map((e) => SwitchChannel.fromMap(e.key, e.value))
          .toList(),
      streamUri: map['streamUri'],
      totalOnSeconds: map['totalOnSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'floorId': floorId,
      'name': name,
      'type': type.name,
      'status': status.name,
      'gridRow': gridRow,
      'gridCol': gridCol,
      if (turnedOnAt != null) 'turnedOnAt': turnedOnAt,
      if (maxOnDurationSeconds != null) 'maxOnDurationSeconds': maxOnDurationSeconds,
      if (scheduleStart != null) 'scheduleStart': scheduleStart,
      if (scheduleEnd != null) 'scheduleEnd': scheduleEnd,
      if (channels.isNotEmpty)
        'channels': {for (final c in channels) c.id: c.toMap()},
      if (streamUri != null) 'streamUri': streamUri,
      'totalOnSeconds': totalOnSeconds,
    };
  }
}
