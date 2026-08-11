import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/floor.dart';
import '../models/device.dart';

/// Central service wrapping Firebase Realtime Database.
///
/// Sync design:
/// - The app writes state changes directly to `/devices/{id}` and `/floors/{id}`.
/// - The app SUBSCRIBES to those same paths with `.onValue` streams, so any
///   change made anywhere else (the hardware simulator, or the Cloud
///   Function safety-cutoff worker) is pushed to the app automatically -
///   no polling, no manual refresh.
/// - The Cloud Function (see /functions/index.js) watches devices with
///   type == safetyCritical and forces status -> off if `turnedOnAt`
///   exceeds `maxOnDurationSeconds`, and writes an entry under `/alerts`.
class FirebaseService {
  FirebaseService({DatabaseReference? db}) : _db = db;

  final DatabaseReference? _db;
  final _uuid = const Uuid();

  DatabaseReference get _ref => _db ?? FirebaseDatabase.instance.ref();

  // ---------------- FLOORS ----------------

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
    // also remove devices that belonged to this floor
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

  // ---------------- DEVICES ----------------

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
      return data.entries.map((e) => Device.fromMap(e.key, e.value)).toList();
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

  /// Simple ON/OFF toggle for outlets, irons, scheduled lights.
  Future<void> toggleDevice(Device device) async {
    final turningOn = device.status != DeviceStatus.on;
    final now = DateTime.now().millisecondsSinceEpoch;

    final updates = <String, dynamic>{
      'status': turningOn ? DeviceStatus.on.name : DeviceStatus.off.name,
    };

    if (turningOn) {
      updates['turnedOnAt'] = now;
    } else {
      // accumulate usage time for reporting when turning off
      if (device.turnedOnAt != null) {
        final elapsedSec = ((now - device.turnedOnAt!) / 1000).round();
        updates['totalOnSeconds'] = device.totalOnSeconds + elapsedSec;
        await _logUsage(device.id, elapsedSec);
      }
      updates['turnedOnAt'] = null;
    }

    await _ref.child('devices/${device.id}').update(updates);
  }

  /// Toggle one channel inside a multi-switch gang unit.
  Future<void> toggleChannel(Device device, String channelId) async {
    final channel = device.channels.firstWhere((c) => c.id == channelId);
    await _ref
        .child('devices/${device.id}/channels/$channelId/isOn')
        .set(!channel.isOn);

    // unit-level status reflects whether ANY channel is on
    final anyOn = device.channels
        .map((c) => c.id == channelId ? !c.isOn : c.isOn)
        .any((v) => v);
    await _ref.child('devices/${device.id}/status').set(
        anyOn ? DeviceStatus.on.name : DeviceStatus.off.name);
  }

  Future<void> _logUsage(String deviceId, int elapsedSeconds) async {
    final logId = _uuid.v4();
    await _ref.child('usageLogs/$deviceId/$logId').set({
      'endedAt': DateTime.now().millisecondsSinceEpoch,
      'durationSeconds': elapsedSeconds,
    });
  }

  // ---------------- ALERTS (written by the Cloud Function safety worker) ----------------

  Stream<List<Map<String, dynamic>>> alertsStream() {
    return _ref.child('alerts').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Map<String, dynamic>>[];
      return data.entries
          .map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value)})
          .toList()
        ..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    });
  }

  // ---------------- REPORTING ----------------

  Stream<Map<String, dynamic>> usageLogsForDevice(String deviceId) {
    return _ref.child('usageLogs/$deviceId').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      return data == null ? {} : Map<String, dynamic>.from(data);
    });
  }
}
