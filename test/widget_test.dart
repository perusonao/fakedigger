import 'package:fakedigger/game/game_controller.dart';
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
    expect(find.textContaining('ラウンド'), findsOneWidget);
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

  testWidgets('自分（先頭プレイヤー）に「あなた」バッジが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameScreen())),
    );
    expect(find.text('あなた'), findsOneWidget);
  });

  testWidgets('各プレイヤーにターゲット宝石アイコンが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameScreen())),
    );
    final diamonds = find.descendant(
      of: find.byType(PlayerTile),
      matching: find.byIcon(Icons.diamond),
    );
    expect(diamonds, findsNWidgets(4));
  });

  testWidgets('下部バーには戦略カードと手札のみ（ターゲット・メモは無し）', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameScreen())),
    );
    expect(find.text('戦略カード'), findsOneWidget);
    expect(find.textContaining('手札'), findsWidgets);
    final bottomBarTargetIcon = find.descendant(
      of: find.byType(BottomActionBar),
      matching: find.byIcon(Icons.diamond),
    );
    expect(bottomBarTargetIcon, findsNothing);
    final bottomBarMemoIcon = find.descendant(
      of: find.byType(BottomActionBar),
      matching: find.byIcon(Icons.edit_note),
    );
    expect(bottomBarMemoIcon, findsNothing);
  });

  testWidgets('プレイヤーをタップすると手札モーダル。自分はおもて、他は裏', (tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen()),
      ),
    );

    // 山札1を2回発掘して、自分(0)と次のプレイヤー(1)の手札に1枚ずつ持たせる。
    container.read(gameProvider.notifier).dig(0);
    container.read(gameProvider.notifier).dig(0);
    await tester.pump();

    final tiles = find.byType(PlayerTile);
    expect(tiles, findsNWidgets(4));

    // 自分（先頭）のアイコンをタップ → おもて（HandTile）が見える。
    await tester.tap(tiles.at(0));
    await tester.pumpAndSettle();
    expect(find.byType(HandTile), findsOneWidget);
    expect(find.byType(HandBackTile), findsNothing);
    Navigator.of(tester.element(find.byType(HandTile))).pop();
    await tester.pumpAndSettle();

    // 他プレイヤーのアイコンをタップ → 裏向き（HandBackTile）のみ。
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle();
    expect(find.byType(HandBackTile), findsOneWidget);
    expect(find.byType(HandTile), findsNothing);
  });

  testWidgets('戦略カード一覧を開くとスワイプなしで10枚すべて確認できる', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameScreen())),
    );
    await tester.tap(find.text('戦略カード'));
    await tester.pumpAndSettle();
    expect(find.byType(ActionCard), findsNWidgets(10));
    for (final title in const [
      '発掘', '鑑定', '調査', '整地', '埋葬', '強奪', '独占', '捏造', '保護', '取引', //
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });
}
