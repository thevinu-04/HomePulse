import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';

class AddDeviceScreen extends StatefulWidget {
  final String floorId;
  final int gridRow;
  final int gridCol;
  final Device? device;
  final FirebaseService? service;

  const AddDeviceScreen({
    super.key,
    required this.floorId,
    required this.gridRow,
    required this.gridCol,
    this.device,
    this.service,
  });

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameCtrl = TextEditingController();
  final _maxDurationCtrl = TextEditingController(text: '900');
  final _channelCountCtrl = TextEditingController(text: '3');
  final _streamUriCtrl = TextEditingController(
    text: 'mock://camera/stream.jpg',
  );
  late final FirebaseService _service = widget.service ?? FirebaseService();

  DeviceType _type = DeviceType.outlet;
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 23, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      final device = widget.device!;
      _nameCtrl.text = device.name;
      _type = device.type;
      _maxDurationCtrl.text = (device.maxOnDurationSeconds ?? 900).toString();
      _channelCountCtrl.text = device.channels.length.toString();
      _streamUriCtrl.text = device.streamUri ?? 'mock://camera/stream.jpg';
      if (device.scheduleStart != null) {
        final parts = device.scheduleStart!.split(':');
        if (parts.length == 2) {
          _start = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 18,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      if (device.scheduleEnd != null) {
        final parts = device.scheduleEnd!.split(':');
        if (parts.length == 2) {
          _end = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 23,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    List<SwitchChannel> channels = [];
    if (_type == DeviceType.multiSwitch) {
      final count = int.tryParse(_channelCountCtrl.text) ?? 3;
      channels =
          (widget.device?.channels.isNotEmpty == true &&
              widget.device!.channels.length == count)
          ? widget.device!.channels
          : List.generate(
              count,
              (i) => SwitchChannel(
                id: 'ch${i + 1}',
                label: 'Switch ${i + 1}',
                isOn: false,
              ),
            );
    }

    final baseDevice =
        widget.device ??
        Device(
          id: const Uuid().v4(),
          floorId: widget.floorId,
          name: _nameCtrl.text.trim(),
          type: _type,
          status: DeviceStatus.off,
          gridRow: widget.gridRow,
          gridCol: widget.gridCol,
        );

    final device = baseDevice.copyWith(
      floorId: widget.floorId,
      name: _nameCtrl.text.trim(),
      type: _type,
      status: widget.device?.status ?? DeviceStatus.off,
      gridRow: widget.gridRow,
      gridCol: widget.gridCol,
      maxOnDurationSeconds: _type == DeviceType.safetyCritical
          ? int.tryParse(_maxDurationCtrl.text)
          : null,
      scheduleStart: _type == DeviceType.scheduledLight ? _fmt(_start) : null,
      scheduleEnd: _type == DeviceType.scheduledLight ? _fmt(_end) : null,
      channels: channels,
      streamUri: _type == DeviceType.camera ? _streamUriCtrl.text.trim() : null,
    );

    if (widget.device != null) {
      await _service.updateDevice(device);
    } else {
      await _service.addDevice(device);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.device != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Device' : 'Add Device')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Device name',
              hintText: 'e.g. Living Room Iron',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DeviceType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Device type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: DeviceType.outlet,
                child: Text('Electrical Outlet'),
              ),
              DropdownMenuItem(
                value: DeviceType.multiSwitch,
                child: Text('Multi-Switch Unit'),
              ),
              DropdownMenuItem(
                value: DeviceType.safetyCritical,
                child: Text('Safety-Critical (Iron etc.)'),
              ),
              DropdownMenuItem(
                value: DeviceType.scheduledLight,
                child: Text('Scheduled Light'),
              ),
              DropdownMenuItem(
                value: DeviceType.camera,
                child: Text('Security Camera'),
              ),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 20),
          ..._typeSpecificFields(),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(isEditing ? 'Save Changes' : 'Add Device'),
          ),
        ],
      ),
    );
  }

  List<Widget> _typeSpecificFields() {
    switch (_type) {
      case DeviceType.safetyCritical:
        return [
          TextField(
            controller: _maxDurationCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max continuous ON duration (seconds)',
              helperText: 'Backend will auto shut-off and alert if exceeded',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case DeviceType.multiSwitch:
        return [
          TextField(
            controller: _channelCountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of switches in this unit (2-5)',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case DeviceType.scheduledLight:
        return [
          ListTile(
            title: const Text('Auto ON time'),
            trailing: Text(_fmt(_start)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _start,
              );
              if (picked != null) setState(() => _start = picked);
            },
          ),
          ListTile(
            title: const Text('Auto OFF time'),
            trailing: Text(_fmt(_end)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _end,
              );
              if (picked != null) setState(() => _end = picked);
            },
          ),
        ];
      case DeviceType.camera:
        return [
          TextField(
            controller: _streamUriCtrl,
            decoration: const InputDecoration(
              labelText: 'Mock snapshot / stream URI',
              border: OutlineInputBorder(),
            ),
          ),
        ];
      case DeviceType.outlet:
        return [
          const Text('No extra configuration needed for a plain outlet.'),
        ];
    }
  }
}
