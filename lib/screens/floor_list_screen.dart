import 'package:flutter/material.dart';
import '../models/floor.dart';
import '../services/firebase_service.dart';
import 'add_floor_screen.dart';
import 'floor_grid_screen.dart';
import 'alerts_screen.dart';

class FloorListScreen extends StatefulWidget {
  const FloorListScreen({super.key});

  @override
  State<FloorListScreen> createState() => _FloorListScreenState();
}

class _FloorListScreenState extends State<FloorListScreen> {
  final _service = FirebaseService();

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
        ],
      ),
      body: StreamBuilder<List<Floor>>(
        stream: _service.floorsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final floors = snapshot.data!;
          if (floors.isEmpty) {
            return const Center(
              child: Text('No floors yet. Tap + to add your first floor.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: floors.length,
            itemBuilder: (context, i) {
              final floor = floors[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.layers_outlined, size: 32),
                  title: Text(floor.name),
                  subtitle: Text('${floor.gridRows} x ${floor.gridCols} grid'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FloorGridScreen(floor: floor),
                    ),
                  ),
                ),
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
          MaterialPageRoute(builder: (_) => const AddFloorScreen()),
        ),
      ),
    );
  }
}
