import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/floor.dart';
import '../services/firebase_service.dart';
import 'add_floor_screen.dart';
import 'floor_grid_screen.dart';

class MyFloorsScreen extends StatelessWidget {
  const MyFloorsScreen({super.key, required this.service});

  final FirebaseService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Floors')),
      body: StreamBuilder<List<Floor>>(
        stream: service.floorsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final floors = snapshot.data ?? <Floor>[];
          if (floors.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _openFloorEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Create your first floor'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: floors.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _FloorListCard(
              floor: floors[index],
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFloorEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add floor'),
      ),
    );
  }

  void _openFloorEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFloorScreen(service: service)),
    );
  }
}

class _FloorListCard extends StatelessWidget {
  const _FloorListCard({required this.floor, required this.service});

  final Floor floor;
  final FirebaseService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Device>>(
      stream: service.devicesForFloorStream(floor.id),
      builder: (context, snapshot) {
        final deviceCount = snapshot.data?.length ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        floor.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Floor actions',
                      onSelected: (value) => _handleAction(context, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit floor')),
                        PopupMenuItem(value: 'delete', child: Text('Delete floor')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('$deviceCount devices | ${floor.gridRows} x ${floor.gridCols} map'),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FloorGridScreen(floor: floor)),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View floor map'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddFloorScreen(floor: floor, service: service),
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete floor?'),
        content: Text('This removes ${floor.name} and all of its devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await service.deleteFloor(floor.id);
    }
  }
}
