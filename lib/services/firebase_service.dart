import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/floor.dart';
import '../models/device.dart';

class FirebaseService {
  FirebaseService({DatabaseReference? db}) : _db = db;

  final DatabaseReference? _db;
  final _uuid = const Uuid();
  bool _isEnforcingSafetyCutoffs = false;
  bool _isEnforcingSchedules = false;

  DatabaseReference get _ref => _db ?? FirebaseDatabase.instance.ref();

  Stream<List<Floor>> floorsStream() {
    return _ref.child('floors').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Floor>[];
      return data.entries.map((e) => Floor.fromMap(e.key, e.value)).toList();
    });
  }

  Future<String> addFloor({
    required String name,
    String? imageAsset,
    int gridRows = 6,
    int gridCols = 6,
  }) async {
    final id = _uuid.v4();
    final floor = Floor(
      id: id,
      name: name,
      imageAsset: imageAsset,
      gridRows: gridRows,
      gridCols: gridCols,
    );
    await _ref.child('floors/$id').set(floor.toMap());
    return id;
  }

  Future<void> updateFloor(Floor floor) async {
    await _ref.child('floors/${floor.id}').update(floor.toMap());
  }

  Future<void> deleteFloor(String floorId) async {
    await _ref.child('floors/$floorId').remove();
    final snap = await _ref
        .child('devices')
        .orderByChild('floorId')
        .equalTo(floorId)
        .get();
    final data = snap.value as Map<dynamic, dynamic>?;
    if (data != null) {
      for (final key in data.keys) {
        await _ref.child('devices/$key').remove();
      }
    }
  }

  Stream<List<Device>> devicesStream() {
    return _ref.child('devices').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Device>[];
      return data.entries.map((e) => Device.fromMap(e.key, e.value)).toList();
    });
  }

  Stream<List<Device>> devicesForFloorStream(String floorId) {
    return _ref
        .child('devices')
        .orderByChild('floorId')
        .equalTo(floorId)
        .onValue
        .map((event) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data == null) return <Device>[];
          return data.entries
              .map((e) => Device.fromMap(e.key, e.value))
              .toList();
        });
  }

  Stream<Device?> deviceStream(String deviceId) {
    return _ref.child('devices/$deviceId').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      return Device.fromMap(deviceId, data);
    });
  }

  Future<String> addDevice(Device device) async {
    final id = device.id.isNotEmpty ? device.id : _uuid.v4();
    await _ref.child('devices/$id').set(device.toMap());
    return id;
  }

  Future<void> updateDevice(Device device) async {
    await _ref.child('devices/${device.id}').update(device.toMap());
  }

  Future<void> deleteDevice(String deviceId) async {
    await _ref.child('devices/$deviceId').remove();
  }

  Future<void> toggleDevice(Device device) async {
    final turningOn = device.status != DeviceStatus.on;
    final now = DateTime.now().millisecondsSinceEpoch;

    final updates = <String, dynamic>{
      'status': turningOn ? DeviceStatus.on.name : DeviceStatus.off.name,
    };

    if (turningOn) {
      updates['turnedOnAt'] = now;
    } else {
      if (device.turnedOnAt != null) {
        final elapsedSec = ((now - device.turnedOnAt!) / 1000).round();
        updates['totalOnSeconds'] = device.totalOnSeconds + elapsedSec;
        await _logUsage(device.id, elapsedSec);
      }
      updates['turnedOnAt'] = null;
    }

    await _ref.child('devices/${device.id}').update(updates);
  }

  Future<void> toggleChannel(Device device, String channelId) async {
    final channel = device.channels.firstWhere((c) => c.id == channelId);
    final isTurningOn = !channel.isOn;
    final wasAnyOn = device.channels.any((c) => c.isOn);
    final isAnyOn = device.channels
        .map((c) => c.id == channelId ? !c.isOn : c.isOn)
        .any((v) => v);
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'channels/$channelId/isOn': isTurningOn,
      'status': isAnyOn ? DeviceStatus.on.name : DeviceStatus.off.name,
    };

    if (!wasAnyOn && isAnyOn) {
      updates['turnedOnAt'] = now;
    } else if (wasAnyOn && !isAnyOn) {
      if (device.turnedOnAt != null) {
        final elapsedSeconds = ((now - device.turnedOnAt!) / 1000).round();
        updates['totalOnSeconds'] = device.totalOnSeconds + elapsedSeconds;
        await _logUsage(device.id, elapsedSeconds);
      }
      updates['turnedOnAt'] = null;
    }

    await _ref.child('devices/${device.id}').update(updates);
  }

  Future<void> enforceScheduledLights() async {
    if (_isEnforcingSchedules) {
      return;
    }
    _isEnforcingSchedules = true;

    try {
      final devicesSnapshot = await _ref.child('devices').get();
      final devices = devicesSnapshot.value as Map<dynamic, dynamic>? ?? {};
      final now = DateTime.now();
      final nowMilliseconds = now.millisecondsSinceEpoch;

      for (final entry in devices.entries) {
        final deviceId = entry.key.toString();
        final device = Map<dynamic, dynamic>.from(entry.value as Map);
        if (device['type'] != DeviceType.scheduledLight.name) {
          continue;
        }

        final start = _minutesFromTime(device['scheduleStart']);
        final end = _minutesFromTime(device['scheduleEnd']);
        if (start == null || end == null || start == end) {
          continue;
        }

        final currentMinutes = now.hour * 60 + now.minute;
        final shouldBeOn = start < end
            ? currentMinutes >= start && currentMinutes < end
            : currentMinutes >= start || currentMinutes < end;
        final isOn = device['status'] == DeviceStatus.on.name;
        if (isOn == shouldBeOn) {
          continue;
        }

        final deviceRef = _ref.child('devices/$deviceId');
        int? completedSessionSeconds;
        final transaction = await deviceRef.runTransaction((currentValue) {
          if (currentValue is! Map) {
            return Transaction.abort();
          }
          final current = Map<dynamic, dynamic>.from(currentValue);
          if (current['type'] != DeviceType.scheduledLight.name ||
              (current['status'] == DeviceStatus.on.name) == shouldBeOn) {
            return Transaction.abort();
          }

          if (shouldBeOn) {
            return Transaction.success({
              ...current,
              'status': DeviceStatus.on.name,
              'turnedOnAt': nowMilliseconds,
            });
          }

          final turnedOnAt = current['turnedOnAt'] as int?;
          completedSessionSeconds = turnedOnAt == null
              ? null
              : ((nowMilliseconds - turnedOnAt) / 1000).round();
          return Transaction.success({
            ...current,
            'status': DeviceStatus.off.name,
            'turnedOnAt': null,
            'totalOnSeconds':
                (current['totalOnSeconds'] as int? ?? 0) +
                (completedSessionSeconds ?? 0),
          });
        });

        if (transaction.committed && completedSessionSeconds != null) {
          await _logUsage(deviceId, completedSessionSeconds!);
        }
      }
    } finally {
      _isEnforcingSchedules = false;
    }
  }

  int? _minutesFromTime(dynamic value) {
    if (value is! String) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  Future<void> enforceSafetyCutoffs() async {
    if (_isEnforcingSafetyCutoffs) {
      return;
    }
    _isEnforcingSafetyCutoffs = true;

    try {
      final devicesSnapshot = await _ref.child('devices').get();
      final devices = devicesSnapshot.value as Map<dynamic, dynamic>? ?? {};
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final entry in devices.entries) {
        final deviceId = entry.key.toString();
        final device = Map<dynamic, dynamic>.from(entry.value as Map);
        if (device['type'] != DeviceType.safetyCritical.name ||
            device['status'] != DeviceStatus.on.name ||
            device['turnedOnAt'] is! int ||
            device['maxOnDurationSeconds'] is! int) {
          continue;
        }

        final turnedOnAt = device['turnedOnAt'] as int;
        final durationSeconds = ((now - turnedOnAt) / 1000).round();
        if (durationSeconds < (device['maxOnDurationSeconds'] as int)) {
          continue;
        }

        final deviceRef = _ref.child('devices/$deviceId');
        final transaction = await deviceRef.runTransaction((currentValue) {
          if (currentValue is! Map) {
            return Transaction.abort();
          }
          final current = Map<dynamic, dynamic>.from(currentValue);
          if (current['status'] != DeviceStatus.on.name ||
              current['turnedOnAt'] != turnedOnAt) {
            return Transaction.abort();
          }
          return Transaction.success({
            ...current,
            'status': DeviceStatus.off.name,
            'turnedOnAt': null,
            'totalOnSeconds':
                (current['totalOnSeconds'] as int? ?? 0) + durationSeconds,
          });
        });

        if (!transaction.committed) {
          continue;
        }

        await _logUsage(deviceId, durationSeconds);
        final floorSnapshot = await _ref
            .child('floors/${device['floorId']}')
            .get();
        final floor = floorSnapshot.value as Map<dynamic, dynamic>? ?? {};
        await _ref.child('alerts').push().set({
          'deviceId': deviceId,
          'deviceName': device['name'] ?? 'Safety device',
          'floorName': floor['name'] ?? 'Unknown floor',
          'status': DeviceStatus.off.name,
          'severity': 'safetyCutoff',
          'message':
              '${floor['name'] ?? 'Unknown floor'}: ${device['name'] ?? 'Safety device'} was switched off after reaching its safety limit.',
          'timestamp': now,
        });
      }
    } finally {
      _isEnforcingSafetyCutoffs = false;
    }
  }

  Future<void> _logUsage(String deviceId, int elapsedSeconds) async {
    final logId = _uuid.v4();
    await _ref.child('usageLogs/$deviceId/$logId').set({
      'endedAt': DateTime.now().millisecondsSinceEpoch,
      'durationSeconds': elapsedSeconds,
    });
  }

  Stream<List<Map<String, dynamic>>> alertsStream() {
    return _ref.child('alerts').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Map<String, dynamic>>[];
      return data.entries
          .map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)})
          .toList()
        ..sort(
          (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
        );
    });
  }

  Future<void> clearAlert(String alertId) {
    return _ref.child('alerts/$alertId').remove();
  }

  Future<void> clearAllAlerts() {
    return _ref.child('alerts').remove();
  }

  Stream<Map<String, dynamic>> usageLogsForDevice(String deviceId) {
    return _ref.child('usageLogs/$deviceId').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      return data == null ? {} : Map<String, dynamic>.from(data);
    });
  }

  Stream<Map<String, dynamic>> usageLogsStream() {
    return _ref.child('usageLogs').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      return data == null ? {} : Map<String, dynamic>.from(data);
    });
  }
}
