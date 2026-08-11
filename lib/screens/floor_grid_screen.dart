import 'package:flutter/material.dart';
import '../models/floor.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';
import '../widgets/device_tile.dart';
import 'add_device_screen.dart';
import 'device_detail_screen.dart';

/// Shows the floor's background image (if any) with an abstract grid
/// overlaid on top. Each occupied grid cell renders a DeviceTile that
/// reacts live to Firebase updates - no manual refresh needed.
class FloorGridScreen extends StatefulWidget {
  final Floor floor;
  const FloorGridScreen({super.key, required this.floor});

  @override
  State<FloorGridScreen> createState() => _FloorGridScreenState();
}

class _FloorGridScreenState extends State<FloorGridScreen> {
  final _service = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final floor = widget.floor;
    return Scaffold(
      appBar: AppBar(title: Text(floor.name)),
      body: StreamBuilder<List<Device>>(
        stream: _service.devicesForFloorStream(floor.id),
        builder: (context, snapshot) {
          final devices = snapshot.data ?? [];
          final byCell = {
            for (final d in devices) '${d.gridRow}_${d.gridCol}': d,
          };

          return Stack(
            children: [
              if (floor.imageAsset != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(floor.imageAsset!, fit: BoxFit.contain),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Compute the aspect ratio each cell needs so that
                    // gridCols x gridRows exactly fills the available
                    // width AND height, instead of forcing square cells
                    // that only use up part of the screen.
                    const spacing = 6.0;
                    final cellWidth = (constraints.maxWidth -
                            spacing * (floor.gridCols - 1)) /
                        floor.gridCols;
                    final cellHeight = (constraints.maxHeight -
                            spacing * (floor.gridRows - 1)) /
                        floor.gridRows;
                    final aspectRatio = cellWidth / cellHeight;

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: floor.gridCols,
                        childAspectRatio: aspectRatio,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      itemCount: floor.gridRows * floor.gridCols,
                      itemBuilder: (context, index) {
                        final row = index ~/ floor.gridCols;
                        final col = index % floor.gridCols;
                        final device = byCell['${row}_$col'];

                        if (device == null) {
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddDeviceScreen(
                                  floorId: floor.id,
                                  gridRow: row,
                                  gridCol: col,
                                ),
                              ),
                            ),
                            child: DottedEmptyCell(),
                          );
                        }
                        return DeviceTile(
                          device: device,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeviceDetailScreen(deviceId: device.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DottedEmptyCell extends StatelessWidget {
  const DottedEmptyCell({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.add, color: Colors.grey, size: 18),
      ),
    );
  }
}