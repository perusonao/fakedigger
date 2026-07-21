import 'dart:math';

import 'package:fakedigger/game/game_controller.dart';
import 'package:fakedigger/game/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<HandCard> hand(List<Gem> gems) => [for (final g in gems) HandCard(g)];

void main() {
  group('scoreHand', () {
    test('黒は-2、白は+1', () {
      expect(scoreHand(hand([Gem.black, Gem.black]), Gem.blue), -4);
      expect(scoreHand(hand([Gem.white, Gem.white]), Gem.blue), 2);
    });

    test('ターゲット一致は+3、不一致は0', () {
      expect(scoreHand(hand([Gem.blue]), Gem.blue), 3);
      expect(scoreHand(hand([Gem.red]), Gem.blue), 0);
    });

    test('黒を除く5色で+10ボーナス', () {
      final full = hand([Gem.white, Gem.red, Gem.blue, Gem.yellow, Gem.green]);
      // 白+1、青(ターゲット)+3、赤/黄/緑は0 → 4点 + 5色ボーナス10 = 14点。
      expect(scoreHand(full, Gem.blue), 14);
    });

    test('同色5枚で+20ボーナス', () {
      final five = hand([Gem.blue, Gem.blue, Gem.blue, Gem.blue, Gem.blue]);
      // 青×5=15点 + 同色5枚ボーナス20 = 35点。
      expect(scoreHand(five, Gem.blue), 35);
    });

    test('doubled の札は得点2倍', () {
      final cards = [const HandCard(Gem.blue, doubled: true)];
      expect(scoreHand(cards, Gem.blue), 6);
    });

    test('空の手札は0点', () {
      expect(scoreHand(const [], Gem.blue), 0);
    });
  });

  group('buildDecks', () {
    test('5枚ずつ8山・合計40枚・黒は12枚', () {
      final decks = buildDecks(Random(1));
      expect(decks.length, 8);
      expect(decks.every((d) => d.count == 5), isTrue);
      final all = [for (final d in decks) ...d.cards];
      expect(all.length, 40);
      expect(all.where((g) => g == Gem.black).length, 12);
    });
  });

  group('GameController', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(
        overrides: [
          gameProvider.overrideWith(() => GameController(random: Random(1)))
        ],
      );
    });
    tearDown(() => container.dispose());

    GameState s() => container.read(gameProvider);
    GameController c() => container.read(gameProvider.notifier);

    test('初期状態は4人・ラウンド1・手番0', () {
      expect(s().players.length, 4);
      expect(s().round, 1);
      expect(s().currentPlayer, 0);
      expect(s().phase, GamePhase.playing);
    });

    test('発掘で手札が増え、ワーカーが減り、手番が進む', () {
      final before = s().players[0].workers;
      c().dig(0);
      expect(s().players[0].hand.length, 1);
      expect(s().players[0].workers, before - 1);
      expect(s().currentPlayer, 1);
    });

    test('全員のワーカーが尽きるとラウンドが進みスタートPが移動', () {
      // 4人 × 2ワーカー = 8回発掘するとラウンド2へ。
      for (var i = 0; i < 8; i++) {
        if (!s().isOver) c().dig(i % 8);
      }
      expect(s().round, 2);
      expect(s().startPlayer, 1);
      expect(s().currentPlayer, 1);
      expect(s().players.every((p) => p.workers == 2), isTrue);
    });

    test('山札が尽きるとゲーム終了', () {
      // 同じ山を5回発掘すれば空になる（各手番で発掘者は変わるが山は空く）。
      for (var i = 0; i < 5; i++) {
        if (!s().isOver) c().dig(0);
      }
      expect(s().isOver, isTrue);
      expect(s().decks[0].isEmpty, isTrue);
    });

    test('山札の最後の1枚は doubled になる', () {
      for (var i = 0; i < 5; i++) {
        if (!s().isOver) c().dig(0);
      }
      final doubledExists =
          s().players.any((p) => p.hand.any((h) => h.doubled));
      expect(doubledExists, isTrue);
    });

    test('リセットで初期状態に戻る', () {
      c().dig(0);
      c().reset();
      expect(s().players.every((p) => p.hand.isEmpty), isTrue);
      expect(s().round, 1);
    });
  });

  group('CPU（仮実装）', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(
        overrides: [
          gameProvider.overrideWith(() => GameController(
                random: Random(1),
                cpuThinkDelay: const Duration(milliseconds: 5),
              )),
        ],
      );
    });
    tearDown(() => container.dispose());

    GameState s() => container.read(gameProvider);
    GameController c() => container.read(gameProvider.notifier);

    test('自分（0）の手番でCPUは動かない', () async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(s().currentPlayer, 0);
      expect(s().players.every((p) => p.hand.isEmpty), isTrue);
    });

    test('自分が発掘するとCPUの手番になり、待つと自動で発掘して手番が進む', () async {
      c().dig(0);
      expect(s().currentPlayer, 1);
      expect(s().players[1].hand, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(s().players[1].hand.length, 1);
      expect(s().currentPlayer, isNot(1));
    });

    test('リセットするとCPUの予約タイマーが取り消される', () async {
      c().dig(0);
      expect(s().currentPlayer, 1);
      c().reset();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      // タイマーが取り消されていれば、リセット後の状態のまま変化しない。
      expect(s().currentPlayer, 0);
      expect(s().players.every((p) => p.hand.isEmpty), isTrue);
    });
  });
}
