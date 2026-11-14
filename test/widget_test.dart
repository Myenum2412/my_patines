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
  });
}
