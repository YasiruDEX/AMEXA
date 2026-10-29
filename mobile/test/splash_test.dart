import 'package:amexa_meals/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Splash shows icons then reveals the meal app', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: SplashGate(child: Text('Meals ready'))));
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(find.text('Meals ready'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Meals ready'), findsOneWidget);
  });
  testWidgets('Reduced motion skips the animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SplashGate(child: Text('Meals ready')))));
    await tester.pumpAndSettle();
    expect(find.text('Meals ready'), findsOneWidget);
  });
}
