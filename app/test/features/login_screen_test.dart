import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('login validates empty fields before calling the server', (tester) async {
    final controller = FakeAuthController(const AuthSignedOut());
    await tester.pumpWidget(harness(controller, const LoginScreen()));

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your username'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(controller.attempts, isEmpty);
  });

  testWidgets('login submits trimmed username and shows server errors', (tester) async {
    final controller = FakeAuthController(const AuthSignedOut(), loginError: 'Invalid username or password');
    await tester.pumpWidget(harness(controller, const LoginScreen()));

    await tester.enterText(find.byType(TextFormField).at(0), '  asha ');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret-pass');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(controller.attempts, [('asha', 'secret-pass')]);
    expect(find.text('Invalid username or password'), findsOneWidget);
  });

  testWidgets('shows the session-expired notice', (tester) async {
    final controller = FakeAuthController(const AuthSignedOut(message: 'Your session has expired.'));
    await tester.pumpWidget(harness(controller, const LoginScreen()));
    expect(find.text('Your session has expired.'), findsOneWidget);
  });
}
