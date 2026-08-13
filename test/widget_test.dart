import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_grid/models/device.dart';
import 'package:home_grid/models/floor.dart';
import 'package:home_grid/screens/floor_list_screen.dart';
import 'package:home_grid/services/firebase_service.dart';

class FakeFirebaseService extends FirebaseService {
  @override
  Stream<List<Floor>> floorsStream() {
    return Stream.value([
      Floor(id: 'floor-1', name: 'Main Floor', gridRows: 5, gridCols: 4),
    ]);
  }

  @override
  Stream<List<Device>> devicesStream() => Stream.value(const <Device>[]);

  @override
  Stream<List<Map<String, dynamic>>> alertsStream() =>
      Stream.value(const <Map<String, dynamic>>[]);
}

void main() {
  testWidgets('dashboard shows the floor selector and reports navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FloorListScreen(service: FakeFirebaseService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Main Floor'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
  });
}
