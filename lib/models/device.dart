enum DeviceType { outlet, multiSwitch, safetyCritical, scheduledLight, camera }

enum DeviceStatus { on, off, error, disconnected }

DeviceType deviceTypeFromString(String s) => DeviceType.values.firstWhere(
  (e) => e.name == s,
  orElse: () => DeviceType.outlet,
);

DeviceStatus deviceStatusFromString(String s) => DeviceStatus.values.firstWhere(
  (e) => e.name == s,
  orElse: () => DeviceStatus.disconnected,
);

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

  final int? turnedOnAt;

  final int? maxOnDurationSeconds;

  final String? scheduleStart;
  final String? scheduleEnd;

  final List<SwitchChannel> channels;

  final String? streamUri;

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

  Device copyWith({
    String? id,
    String? floorId,
    String? name,
    DeviceType? type,
    DeviceStatus? status,
    int? gridRow,
    int? gridCol,
    int? turnedOnAt,
    int? maxOnDurationSeconds,
    String? scheduleStart,
    String? scheduleEnd,
    List<SwitchChannel>? channels,
    String? streamUri,
    int? totalOnSeconds,
  }) {
    return Device(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      gridRow: gridRow ?? this.gridRow,
      gridCol: gridCol ?? this.gridCol,
      turnedOnAt: turnedOnAt ?? this.turnedOnAt,
      maxOnDurationSeconds: maxOnDurationSeconds ?? this.maxOnDurationSeconds,
      scheduleStart: scheduleStart ?? this.scheduleStart,
      scheduleEnd: scheduleEnd ?? this.scheduleEnd,
      channels: channels ?? this.channels,
      streamUri: streamUri ?? this.streamUri,
      totalOnSeconds: totalOnSeconds ?? this.totalOnSeconds,
    );
  }

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
      if (maxOnDurationSeconds != null)
        'maxOnDurationSeconds': maxOnDurationSeconds,
      if (scheduleStart != null) 'scheduleStart': scheduleStart,
      if (scheduleEnd != null) 'scheduleEnd': scheduleEnd,
      if (channels.isNotEmpty)
        'channels': {for (final c in channels) c.id: c.toMap()},
      if (streamUri != null) 'streamUri': streamUri,
      'totalOnSeconds': totalOnSeconds,
    };
  }
}
