import 'package:fakedigger/game/game_controller.dart';
import 'package:fakedigger/game/models.dart';
import 'package:fakedigger/main.dart';
import 'package:fakedigger/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// CPUの手番進行タイマー（最大で自分の待ち+CPU3人分の待ち＋演出）を
/// 使い切り、保留中のタイマーが残らない状態までテストを進める
/// （`flutter_test` はテスト終了時に保留タイマーが残っているとエラーにするため）。
Future<void> drainTurnTimers(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 4));

Widget wrapGameScreen() => ProviderScope(
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const GameScreen(),
      ),
    );

void main() {
  testWidgets('山札を選択して発掘できる（発掘→山札選択→確認→結果告知）', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();
    expect(find.textContaining('R1'), findsOneWidget);

    // 「発掘」戦略カードをタップして選択する。
    await tester.tap(find.text('発掘').first);
    await tester.pump();

    // 山札1をタップする。
    await tester.tap(find.bySemanticsLabel(RegExp('^山札1、')));
    await tester.pumpAndSettle();

    // 確認ダイアログで「発掘する」を選ぶ。
    expect(find.text('発掘する'), findsOneWidget);
    await tester.tap(find.text('発掘する'));
    // CPUの手番（kCpuThinkDelay以降）が進む前に、自分の発掘結果だけを確認する。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 発掘した宝石が告知され、選択した山札は発光したままになる。
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

  testWidgets('山札を長押しすると詳細ダイアログが表示される', (tester) async {
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();

    await tester.longPress(find.bySemanticsLabel(RegExp('^山札1、')));
    await tester.pumpAndSettle();

    expect(find.text('山札1の詳細'), findsOneWidget);
    expect(find.text('この山札を選択'), findsOneWidget);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    await drainTurnTimers(tester);
  });

  testWidgets('自分（先頭プレイヤー）に「あなた」バッジが表示される', (tester) async {
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();
    expect(find.textContaining('あなた'), findsWidgets);
    await drainTurnTimers(tester);
  });

  testWidgets('プレイヤー表示エリアはコンパクトで、ターゲット色は表示しない', (tester) async {
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();
    // ターゲットは常時表示せず、下部ナビゲーションのBottomSheetでのみ見せる。
    // 手札枚数の表示に宝石アイコンを使うが、色はターゲットではなく
    // 中立の金色で統一し、ターゲット色を漏らさない。
    final diamonds = find.descendant(
      of: find.byType(PlayerTile),
      matching: find.byIcon(Icons.diamond),
    );
    expect(diamonds, findsNWidgets(4));
    for (final element in diamonds.evaluate()) {
      final icon = element.widget as Icon;
      expect(icon.color, kGold);
    }
    expect(find.byType(PlayerTile), findsNWidgets(4));
    await drainTurnTimers(tester);
  });

  testWidgets('プレイヤー表示エリアは戦略カードエリアの下に表示される', (tester) async {
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();
    final strategyCenter = tester.getCenter(find.byType(StrategyArea));
    final playerAreaCenter = tester.getCenter(find.byType(PlayerArea));
    expect(playerAreaCenter.dy, greaterThan(strategyCenter.dy));
    await drainTurnTimers(tester);
  });

  testWidgets('自分の手札エリアはプレイヤー表示エリアの下に表示される', (tester) async {
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();
    final playerAreaCenter = tester.getCenter(find.byType(PlayerArea));
    final handAreaCenter = tester.getCenter(find.byType(HandArea));
    expect(handAreaCenter.dy, greaterThan(playerAreaCenter.dy));
    await drainTurnTimers(tester);
  });

  testWidgets('自分の手札をタップすると詳細ダイアログが表示される', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SafeArea(child: Dashboard())),
        ),
      ),
    );
    container.read(gameProvider.notifier).dig(0);
    await tester.pump();

    await tester.tap(find.byType(HandTile).first);
    // 手番以外のプレイヤーの「考え中」スピナーが無限アニメーションのため、
    // pumpAndSettle() は使わず一定時間だけ進める。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('基本得点'), findsOneWidget);
    expect(find.text('選択'), findsOneWidget);
    await tester.tap(find.text('選択'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('他プレイヤーをタップすると手札表示が切り替わり、未鑑定は裏面のみ表示される', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
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

    // 既定では自分の手札がおもてで表示されている。
    expect(find.byType(HandTile), findsOneWidget);
    expect(find.byType(HandBackTile), findsNothing);

    // 他プレイヤー（index 1）のアイコンをタップ → 手札表示エリアが切り替わる。
    final tiles = find.byType(PlayerTile);
    await tester.tap(tiles.at(1));
    // 手番でないプレイヤーの「考え中」スピナーが無限アニメーションのため、
    // pumpAndSettle() は使わず一定時間だけ進める。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 未鑑定なので裏面のみで、中身（HandTile）は見えない。
    expect(find.byType(HandBackTile), findsOneWidget);
    expect(find.byType(HandTile), findsNothing);

    // このカードを「鑑定済み」にする（鑑定戦略の実装前提の状態のみ再現）。
    final state = container.read(gameProvider);
    final revealed = HandCard(
      state.players[1].hand.first.gem,
      revealedToSelf: true,
    );
    final players = [...state.players];
    players[1] = players[1].copyWith(hand: [revealed]);
    container.read(gameProvider.notifier).state =
        state.copyWith(players: players);
    await tester.pump(const Duration(milliseconds: 300));

    // 鑑定済みなのでおもてで見える。
    expect(find.byType(HandTile), findsOneWidget);
    expect(find.byType(HandBackTile), findsNothing);
  });

  testWidgets('下部ナビゲーションからターゲット・推理メモ・ログを開ける', (tester) async {
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();

    await tester.tap(find.text('ターゲット'));
    await tester.pumpAndSettle();
    expect(find.text('あなたのターゲット'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('推理メモ'));
    await tester.pumpAndSettle();
    expect(find.text('推理メモ（あなただけ）'), findsOneWidget);
    await tester.tap(find.text('保存して閉じる'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ログ'));
    await tester.pumpAndSettle();
    expect(find.text('ログ'), findsWidgets);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await drainTurnTimers(tester);
  });

  testWidgets('戦略カードは横スクロールで10枚すべて確認できる', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();
    // 横スクロールのListViewは遅延構築のため、最初は先頭側だけが見える。
    expect(find.text('発掘'), findsOneWidget);
    expect(find.text('取引'), findsNothing);

    await tester.drag(find.byType(StrategyArea), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    // 端までスワイプすると末尾のカードが見える。
    expect(find.text('取引'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await drainTurnTimers(tester);
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('幅${width.toInt()}pxでもレイアウト崩れ（オーバーフロー）が起きない', (tester) async {
      tester.view.physicalSize = Size(width, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapGameScreen());
      await tester.pump();
      expect(tester.takeException(), isNull);

      await drainTurnTimers(tester);
    });
  }

  // 実機でよくある縦画面の高さでも、縦スクロールなしに1画面へ収まり
  // オーバーフローも起きないことを確認する。
  for (final height in [568.0, 667.0, 736.0, 844.0, 926.0]) {
    testWidgets('高さ${height.toInt()}pxでも1画面に収まる（オーバーフローなし）', (tester) async {
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapGameScreen());
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 山札・戦略・プレイヤー・手札の各エリアが縦スクロールを介さず
      // 直接見えている（Dashboard自体が1つのScrollableも持たない）。
      expect(find.byType(DeckArea), findsOneWidget);
      expect(find.byType(StrategyArea), findsOneWidget);
      expect(find.byType(PlayerArea), findsOneWidget);
      expect(find.byType(HandArea), findsOneWidget);

      await drainTurnTimers(tester);
    });
  }

  testWidgets('基準画面サイズ390×844（SafeArea込み）でスクロールなしに収まる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding =
        const FakeViewPadding(top: 47, bottom: 34); // ノッチ・ホームインジケータ相当
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.byType(DeckArea), findsOneWidget);
    expect(find.byType(StrategyArea), findsOneWidget);
    expect(find.byType(PlayerArea), findsOneWidget);
    expect(find.byType(HandArea), findsOneWidget);

    await drainTurnTimers(tester);
  });

  testWidgets('基準画面サイズ390×844で上部バーの手番表示（Tooltip）が省略されない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();

    // 上部バーは文字列でなく色付きドット＋Tooltipで手番を示すため、
    // 省略（ellipsis）が起こり得ない。手番用Tooltipのメッセージが正しく
    // 「あなたの番」を保持していることと、オーバーフローが無いことを確認する。
    expect(
      find.descendant(
        of: find.byType(StatusBar),
        matching:
            find.byWidgetPredicate((w) => w is Tooltip && w.message == 'あなたの番'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await drainTurnTimers(tester);
  });

  testWidgets('戦略カードを長押しすると説明ダイアログが表示される（カード面には説明文を出さない）', (tester) async {
    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();

    // カード面には説明文を表示しない。
    expect(find.text('山札の1番上のカードを手札に加える'), findsNothing);

    await tester.longPress(find.text('発掘').first);
    await tester.pumpAndSettle();

    expect(find.text('山札の1番上のカードを手札に加える'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    await drainTurnTimers(tester);
  });

  testWidgets('タブレット幅では中央寄せの最大幅で表示される', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapGameScreen());
    await tester.pump();

    final box = tester.widget<ConstrainedBox>(
      find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 900,
      ),
    );
    expect(box.constraints.maxWidth, 900);

    await drainTurnTimers(tester);
  });
}
