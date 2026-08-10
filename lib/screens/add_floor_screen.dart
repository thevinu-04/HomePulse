import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// A few bundled sample floor plan images (add these under assets/floorplans/
/// and register them in pubspec.yaml under flutter: assets:).
const samplePlans = <String>[
  'assets/floorplans/sample_1bhk.png',
  'assets/floorplans/sample_2bhk.png',
  'assets/floorplans/sample_studio.png',
];

class AddFloorScreen extends StatefulWidget {
  const AddFloorScreen({super.key});

  @override
  State<AddFloorScreen> createState() => _AddFloorScreenState();
}

class _AddFloorScreenState extends State<AddFloorScreen> {
  final _nameCtrl = TextEditingController();
  final _service = FirebaseService();
  String? _selectedPlan;
  int _rows = 6;
  int _cols = 6;
  bool _saving = false;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await _service.addFloor(
      name: _nameCtrl.text.trim(),
      imageAsset: _selectedPlan,
      gridRows: _rows,
      gridCols: _cols,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Floor')),
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
                child: _stepper('Rows', _rows, (v) => setState(() => _rows = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stepper('Cols', _cols, (v) => setState(() => _cols = v)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Sample floor plan (optional)',
              style: Theme.of(context).textTheme.titleMedium),
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
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Create Floor'),
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
