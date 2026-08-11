import 'package:flutter/material.dart';
import '../models/floor.dart';
import '../services/firebase_service.dart';
import 'add_floor_screen.dart';
import 'floor_grid_screen.dart';
import 'alerts_screen.dart';

class FloorListScreen extends StatefulWidget {
  const FloorListScreen({super.key, FirebaseService? service})
      : _service = service;

  final FirebaseService? _service;

  FirebaseService get service => _service ?? FirebaseService();

  @override
  State<FloorListScreen> createState() => _FloorListScreenState();
}

class _FloorListScreenState extends State<FloorListScreen> {
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
        stream: widget.service.floorsStream(),
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
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Floor actions',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddFloorScreen(
                              floor: floor,
                              service: widget.service,
                            ),
                          ),
                        );
                        return;
                      }

                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete floor?'),
                            content: Text(
                              'This will remove ${floor.name} and all devices assigned to it.',
                            ),
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

                        if (confirm == true) {
                          await widget.service.deleteFloor(floor.id);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
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
          MaterialPageRoute(builder: (_) => AddFloorScreen(service: widget.service)),
        ),
      ),
    );
  }
}
