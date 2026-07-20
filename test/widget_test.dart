import 'package:fakedigger/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the game board and selects a deck', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameScreen())),
    );
    expect(find.text('FakeDigger'), findsOneWidget);
    expect(find.text('あなたのターゲット'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^山札1、')));
    await tester.pumpAndSettle();
    final container = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.bySemanticsLabel(RegExp('^山札1、')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    handle.dispose();
  });

  testWidgets('layoutProviderで縦レイアウトを選べる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [layoutProvider.overrideWith((ref) => AppLayout.portrait)],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    expect(find.byType(PortraitDashboard), findsOneWidget);
    expect(find.byType(LandscapeDashboard), findsNothing);
  });

  testWidgets('layoutProviderで横レイアウトを選べる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [layoutProvider.overrideWith((ref) => AppLayout.landscape)],
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    expect(find.byType(LandscapeDashboard), findsOneWidget);
    expect(find.byType(PortraitDashboard), findsNothing);
  });
}
