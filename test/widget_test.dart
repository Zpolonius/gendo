// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gendo/main.dart';
import 'package:gendo/services/notification_service.dart'; // Import servicen

// Mock af NotificationService så vi ikke kalder den rigtige plugin i test
class MockNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> showTimerCompleteNotification({required String title, required String body, bool isWorkSession = true}) async {}

  @override
  Future<void> scheduleDeadlineNotification({required int id, required String taskTitle, required DateTime dueDate}) async {}

  @override
  Future<void> cancelNotification(int id) async {}
}

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Opret en instans af vores mock service
    final mockNotificationService = MockNotificationService();

    // Build our app and trigger a frame.
    // Her sender vi mock servicen med
    await tester.pumpWidget(GenDoApp(notificationService: mockNotificationService));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}