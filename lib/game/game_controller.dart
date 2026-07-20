import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// ゲーム終了となる手札枚数。
const kHandLimit = 6;

/// 40枚の宝石の色構成（黒は40枚中12枚。合計40枚）。
const _gemComposition = {
  Gem.black: 12,
  Gem.white: 8,
  Gem.red: 5,
  Gem.blue: 5,
  Gem.yellow: 5,
  Gem.green: 5,
};

/// 40枚を生成してシャッフルし、5枚ずつ8山に配る。
List<Deck> buildDecks(Random random) {
  final bag = <Gem>[
    for (final entry in _gemComposition.entries)
      for (var i = 0; i < entry.value; i++) entry.key,
  ]..shuffle(random);
  return [
    for (var i = 0; i < 8; i++) Deck(bag.sublist(i * 5, i * 5 + 5)),
  ];
}

GameState createInitialGame({Random? random}) {
  final rng = random ?? Random();
  const players = [
    PlayerState(
        name: 'アルル',
        color: Color(0xffd86c77),
        avatar: '♛',
        target: Gem.blue,
        role: 'YOU'),
    PlayerState(
        name: 'ゼファ',
        color: Color(0xff46aee8),
        avatar: '⚔',
        target: Gem.red,
        role: 'YP'),
    PlayerState(
        name: 'ノクス', color: Color(0xff76688e), avatar: '☾', target: Gem.green),
    PlayerState(
        name: 'ミア',
        color: Color(0xffe5ad54),
        avatar: '✦',
        target: Gem.yellow,
        role: 'YP'),
  ];
  return GameState(
    decks: buildDecks(rng),
    players: players,
    round: 1,
    startPlayer: 0,
    currentPlayer: 0,
  );
}

class GameController extends Notifier<GameState> {
  GameController({Random? random}) : _random = random;
  final Random? _random;

  @override
  GameState build() => createInitialGame(random: _random);

  /// 現在の手番プレイヤーが [deckIndex] の山札を発掘する。
  ///
  /// - 山札の1番上の宝石を手札に加える。
  /// - 独占状態でない山札の最後の1枚だった場合、その札は得点2倍（doubled）。
  /// - ワーカーを1枚消費し、手番を次へ進める。
  /// - 発掘後に終了条件を判定する。
  void dig(int deckIndex) {
    if (state.isOver) return;
    final me = state.currentPlayer;
    final player = state.players[me];
    if (player.workers <= 0) return;

    final deck = state.decks[deckIndex];
    if (deck.isEmpty) return;

    final gem = deck.top;
    final remaining = deck.cards.sublist(1);
    final wasLast = remaining.isEmpty && deck.monopolizedBy == null;

    final decks = [...state.decks]..[deckIndex] =
        deck.copyWith(cards: remaining);
    final players = [...state.players]..[me] = player.copyWith(
        hand: [...player.hand, HandCard(gem, doubled: wasLast)],
        workers: player.workers - 1,
      );

    state = state.copyWith(decks: decks, players: players);
    _checkEnd();
    if (!state.isOver) _advanceTurn();
  }

  /// 手番プレイヤーがワーカーを使わずに手番を飛ばす（打てるアクションがない等）。
  void skipTurn() {
    if (state.isOver) return;
    _advanceTurn();
  }

  /// 終了条件を判定して状態を更新する。
  /// - いずれかの山札が0枚
  /// - いずれかのプレイヤーの手札が [kHandLimit] 枚
  void _checkEnd() {
    if (state.decks.any((d) => d.isEmpty)) {
      state = state.copyWith(phase: GamePhase.ended, endReason: '山札が尽きました');
      return;
    }
    final full = state.players.indexWhere((p) => p.hand.length >= kHandLimit);
    if (full >= 0) {
      state = state.copyWith(
        phase: GamePhase.ended,
        endReason: '${state.players[full].name} の手札が$kHandLimit枚に達しました',
      );
    }
  }

  /// 手番を、まだワーカーを持つ次のプレイヤーへ時計回りに移す。
  /// 全員のワーカーが尽きていればラウンドを更新する。
  void _advanceTurn() {
    final n = state.players.length;
    for (var step = 1; step <= n; step++) {
      final next = (state.currentPlayer + step) % n;
      if (state.players[next].workers > 0) {
        state = state.copyWith(currentPlayer: next);
        return;
      }
    }
    _nextRound();
  }

  /// 全ワーカーを回収し、スタートプレイヤーを時計回りに進めて次ラウンドへ。
  void _nextRound() {
    final players = [
      for (final p in state.players)
        p.copyWith(workers: PlayerState.kWorkersPerPlayer),
    ];
    final nextStart = (state.startPlayer + 1) % state.players.length;
    state = state.copyWith(
      players: players,
      round: state.round + 1,
      startPlayer: nextStart,
      currentPlayer: nextStart,
    );
  }

  /// ゲームを最初からやり直す。
  void reset() => state = createInitialGame(random: _random);
}

final gameProvider =
    NotifierProvider<GameController, GameState>(GameController.new);
