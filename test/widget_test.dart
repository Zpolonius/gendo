// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:gendo/main.dart';
import 'package:gendo/services/notification_service.dart'; // Import servicen

// Mock af NotificationService så vi ikke kalder den rigtige plugin i test
class MockNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermissions() async {}

  // RETTET: Opdateret til at matche den rigtige showNotification
  @override
  Future<void> showNotification({required int id, required String title, required String body}) async {}

  // RETTET: Opdateret til at matche den rigtige scheduleTaskNotification
  @override
  Future<void> scheduleTaskNotification({required int id, required String title, required String body, required DateTime scheduledDate}) async {}

  @override
  Future<void> cancelNotification(int id) async {}
}

void main() {
  testWidgets('Basic app smoke test', (WidgetTester tester) async {
    // Opret en instans af vores mock service
    final mockNotificationService = MockNotificationService();

    // Build our app and trigger a frame.
    // RETTET: Vi fjerner 'const' og sender mock servicen med
    await tester.pumpWidget(GenDoApp(notificationService: mockNotificationService));

    // Da din app starter på LoginScreen eller MainScreen, vil standard "Counter" testen fejle.
    // Du bør skrive tests der kigger efter widgets der faktisk findes, f.eks.:
    // expect(find.byType(LoginScreen), findsOneWidget);
  });
}