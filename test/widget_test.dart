import 'package:fakedigger/game/game_controller.dart';
import 'package:fakedigger/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 自分の手番開始時に自動で開く戦略モーダルを待つ
/// （250msの遅延＋登場アニメーションの完了）。
Future<void> waitForAutoStrategySheet(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 260));
  await tester.pumpAndSettle();
}

/// 自分／CPUのターン進行タイマー（最大で自分の待ち+CPU3人分の待ち＋演出）を
/// 使い切り、保留中のタイマーが残らない状態までテストを進める
/// （`flutter_test` はテスト終了時に保留タイマーが残っているとエラーにするため）。
Future<void> drainTurnTimers(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 4));

void main() {
  testWidgets('renders the game board and selects a deck', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const GameScreen(),
        ),
      ),
    );
    expect(find.textContaining('ラウンド'), findsOneWidget);

    // ①②自分の手番になり、戦略モーダルが自動で開く。③『発掘』をタップ。
    await waitForAutoStrategySheet(tester);
    expect(find.text('戦略カード（タップして使用）'), findsOneWidget);
    await tester.tap(find.text('発掘').first);
    await tester.pumpAndSettle();

    // ④モーダルが閉じる。⑤⑥山札1をタップ。
    await tester.tap(find.bySemanticsLabel(RegExp('^山札1、')));
    await tester.pumpAndSettle();

    // ⑦確認ダイアログで「発掘する」を選ぶ。
    expect(find.text('発掘する'), findsOneWidget);
    await tester.tap(find.text('発掘する'));
    // CPUの手番（kCpuThinkDelay以降）が進む前に、自分の発掘結果だけを確認する。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // ⑧⑨発掘した宝石が告知され、選択した山札は発光したままになる。
    expect(find.textContaining('の宝石を発掘しました'), findsOneWidget);
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

    await drainTurnTimers(tester);
    handle.dispose();
  });

  testWidgets('自分（先頭プレイヤー）に「あなた」バッジが表示される', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const GameScreen(),
        ),
      ),
    );
    expect(find.text('あなた'), findsOneWidget);
    await drainTurnTimers(tester);
  });

  testWidgets('各プレイヤーにターゲット宝石アイコンが表示される', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const GameScreen(),
        ),
      ),
    );
    final diamonds = find.descendant(
      of: find.byType(PlayerTile),
      matching: find.byIcon(Icons.diamond),
    );
    expect(diamonds, findsNWidgets(4));
    await drainTurnTimers(tester);
  });

  testWidgets('下部バーには戦略カードのみ（手札・ターゲット・メモは無し）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const GameScreen(),
        ),
      ),
    );
    final bar = find.byType(BottomActionBar);
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.style)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.back_hand)),
      findsNothing,
    );
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.diamond)),
      findsNothing,
    );
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.edit_note)),
      findsNothing,
    );
    await drainTurnTimers(tester);
  });

  testWidgets('プレイヤー一覧は山札の下に表示される', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const GameScreen(),
        ),
      ),
    );
    final boardCenter = tester.getCenter(find.byType(BoardPanel));
    final playerBarCenter = tester.getCenter(find.byType(PlayerBar));
    expect(playerBarCenter.dy, greaterThan(boardCenter.dy));
    await drainTurnTimers(tester);
  });

  testWidgets('プレイヤーをタップすると手札モーダル。自分はおもて、他は裏', (tester) async {
    tester.view.physicalSize = const Size(450, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    // このテストは手札モーダルの表裏だけを検証するため、GameScreenの
    // 自動ターン進行（戦略モーダル自動オープン等）に依存しないDashboardを
    // 直接使う。
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SafeArea(child: Dashboard())),
        ),
      ),
    );

    // 山札1を2回発掘して、自分(0)と次のプレイヤー(1)の手札に1枚ずつ持たせる。
    container.read(gameProvider.notifier).dig(0);
    container.read(gameProvider.notifier).dig(0);
    await tester.pump();

    final tiles = find.byType(PlayerTile);
    expect(tiles, findsNWidgets(4));

    // 自分（先頭）のアイコンをタップ → おもて（HandTile）が見える。
    await tester.ensureVisible(tiles.at(0));
    await tester.tap(tiles.at(0));
    // 手番でないプレイヤーの「考え中」スピナーが無限アニメーションのため、
    // pumpAndSettle() は使わず一定時間だけ進める。
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HandTile), findsOneWidget);
    expect(find.byType(HandBackTile), findsNothing);
    Navigator.of(tester.element(find.byType(HandTile))).pop();
    await tester.pump(const Duration(milliseconds: 300));

    // 他プレイヤーのアイコンをタップ → 裏向き（HandBackTile）のみ。
    await tester.ensureVisible(tiles.at(1));
    await tester.tap(tiles.at(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HandBackTile), findsOneWidget);
    expect(find.byType(HandTile), findsNothing);
    Navigator.of(tester.element(find.byType(HandBackTile))).pop();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('戦略カード一覧を開くとスワイプなしで10枚すべて確認できる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const GameScreen(),
        ),
      ),
    );
    // 自分の手番開始で自動的に開く。
    await waitForAutoStrategySheet(tester);
    expect(find.byType(ActionCard), findsNWidgets(10));
    for (final title in const [
      '発掘', '鑑定', '調査', '整地', '埋葬', '強奪', '独占', '捏造', '保護', '取引', //
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    // バリアをタップして閉じ、後片付け。
    await tester.tapAt(const Offset(10, 10));
    await drainTurnTimers(tester);
  });
}
