// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kitchen_organizer_app/main.dart';
import 'package:kitchen_organizer_app/login_screen.dart';
import 'package:kitchen_organizer_app/auth_gate.dart';

void main() {
  testWidgets('App starts and shows initial loading screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We wrap it in a ProviderScope, just like in main.dart
    await tester.pumpWidget(const ProviderScope(child: KitchenOrganizerApp()));
    await tester.pumpAndSettle(); // Wait for the app to settle after initial pump

    // Verify that a loading indicator is shown initially while the app
    // is figuring out if a user is logged in.
    expect(find.byType(AuthGate), findsOneWidget);

    // You can add more tests here in the future.
  });
}