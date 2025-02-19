// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listify/main.dart';

void main() {
  testWidgets('To-do list app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ListifyApp());

    // Verify that the initial state has no tasks.
    expect(find.byType(ListTile), findsNothing);

    // Add a new task.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'New Task');
    await tester.tap(find.text('Add'));
    await tester.pump();

    // Verify that the new task is added.
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('New Task'), findsOneWidget);

    // Delete the task.
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();

    // Verify that the task is deleted.
    expect(find.byType(ListTile), findsNothing);
  });
}