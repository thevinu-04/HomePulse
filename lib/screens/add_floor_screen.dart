import 'package:flutter/material.dart';
import '../models/floor.dart';
import '../services/firebase_service.dart';

const samplePlans = <String>[
  'assets/floorplans/sample_1bhk.png',
  'assets/floorplans/sample_2bhk.png',
  'assets/floorplans/sample_studio.png',
];

class AddFloorScreen extends StatefulWidget {
  const AddFloorScreen({super.key, this.floor, this.service});

  final Floor? floor;
  final FirebaseService? service;

  @override
  State<AddFloorScreen> createState() => _AddFloorScreenState();
}

class _AddFloorScreenState extends State<AddFloorScreen> {
  final _nameCtrl = TextEditingController();
  late final FirebaseService _service = widget.service ?? FirebaseService();
  String? _selectedPlan;
  int _rows = 6;
  int _cols = 6;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.floor != null) {
      _nameCtrl.text = widget.floor!.name;
      _selectedPlan = widget.floor!.imageAsset;
      _rows = widget.floor!.gridRows;
      _cols = widget.floor!.gridCols;
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    if (widget.floor != null) {
      final updated = widget.floor!.copyWith(
        name: name,
        imageAsset: _selectedPlan,
        gridRows: _rows,
        gridCols: _cols,
      );
      await _service.updateFloor(updated);
    } else {
      await _service.addFloor(
        name: name,
        imageAsset: _selectedPlan,
        gridRows: _rows,
        gridCols: _cols,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.floor != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Floor' : 'Add Floor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Floor name',
              hintText: 'e.g. Ground Floor',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Grid size', style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              Expanded(
                child: _stepper(
                  'Rows',
                  _rows,
                  (v) => setState(() => _rows = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stepper(
                  'Cols',
                  _cols,
                  (v) => setState(() => _cols = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Sample floor plan (optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: samplePlans.map((path) {
              final selected = _selectedPlan == path;
              return ChoiceChip(
                label: Text(path.split('/').last),
                selected: selected,
                onSelected: (_) => setState(() => _selectedPlan = path),
              );
            }).toList(),
          ),
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
            label: Text(isEditing ? 'Save Changes' : 'Create Floor'),
          ),
        ],
      ),
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > 2 ? () => onChanged(value - 1) : null,
            ),
            Text('$value'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value < 12 ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
