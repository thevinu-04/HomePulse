// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

void main() {
  testWidgets('floor list shows a floor and action menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FloorListScreen(service: FakeFirebaseService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Main Floor'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
