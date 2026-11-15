import 'package:flutter_test/flutter_test.dart';

import 'package:my_patines/main.dart';

void main() {
  testWidgets('MyPatines login page renders without Google auth', (WidgetTester tester) async {
    await tester.pumpWidget(const MyPatinesApp());

    expect(find.text('Welcome to My Clinic'), findsOneWidget);
    expect(find.text('Email id'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Or'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.textContaining("Don't have a clinic yet?"), findsNothing);
    expect(find.text('Create your clinic'), findsNothing);
  });

  testWidgets('Forgot password opens the reset request page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyPatinesApp());

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('Email or phone number'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });
}
