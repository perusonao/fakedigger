import 'package:fakedigger/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the game board and selects a deck', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: GameScreen())));
    expect(find.text('FakeDigger'), findsOneWidget);
    expect(find.text('あなたのターゲット'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('山札1、5枚'));
    await tester.pumpAndSettle();
    final container = tester.widget<AnimatedContainer>(find.descendant(of: find.bySemanticsLabel('山札1、5枚'), matching: find.byType(AnimatedContainer)).first);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
  });
}
