import 'package:flutter/material.dart';

/// 宝石の6種類。得点計算の基礎になる。
enum Gem { black, white, red, blue, yellow, green }

extension GemInfo on Gem {
  /// ターゲットになり得る色（赤・青・黄・緑）かどうか。
  bool get isTargetable =>
      this == Gem.red ||
      this == Gem.blue ||
      this == Gem.yellow ||
      this == Gem.green;

  String get label => switch (this) {
        Gem.black => '黒',
        Gem.white => '白',
        Gem.red => '赤',
        Gem.blue => '青',
        Gem.yellow => '黄',
        Gem.green => '緑',
      };

  Color get color => switch (this) {
        Gem.black => Colors.black,
        Gem.white => Colors.white,
        Gem.red => Colors.red,
        Gem.blue => Colors.blue,
        Gem.yellow => Colors.amber,
        Gem.green => Colors.green,
      };
}

/// 手札の1枚。山札の最後の1枚を（独占状態でなく）発掘した札は
/// 得点が2倍になるため、その状態を [doubled] で持つ。
@immutable
class HandCard {
  const HandCard(
    this.gem, {
    this.doubled = false,
    this.protected = false,
    this.revealedToSelf = false,
  });
  final Gem gem;
  final bool doubled;

  /// 「保護」戦略の対象になっているか（他プレイヤーの効果を受けない）。
  final bool protected;

  /// 自分（index 0）が「鑑定」でこのカードを見たことがあるか。
  /// 自分自身の手札では常に無関係（自分のカードは常に見える）。
  final bool revealedToSelf;
}

/// 山札。5枚ずつ8個で開始する。先頭 [top] が「1番上」。
@immutable
class Deck {
  const Deck(this.cards, {this.monopolizedBy});
  final List<Gem> cards;

  /// この山札を独占しているプレイヤーのインデックス。null なら独占なし。
  final int? monopolizedBy;

  int get count => cards.length;
  bool get isEmpty => cards.isEmpty;
  Gem get top => cards.first;

  Deck copyWith(
          {List<Gem>? cards, int? monopolizedBy, bool clearMonopoly = false}) =>
      Deck(
        cards ?? this.cards,
        monopolizedBy:
            clearMonopoly ? null : (monopolizedBy ?? this.monopolizedBy),
      );
}

@immutable
class PlayerState {
  const PlayerState({
    required this.name,
    required this.color,
    required this.avatar,
    required this.target,
    this.image,
    this.hand = const [],
    this.workers = kWorkersPerPlayer,
    this.role,
  });

  /// 各プレイヤーが保有するワーカーチップ枚数。
  static const kWorkersPerPlayer = 2;

  final String name;
  final Color color;
  final String avatar;

  /// キャラクターの立ち絵アセット（省略時は [avatar] の文字を表示）。
  final String? image;

  /// このプレイヤーのターゲット色（赤・青・黄・緑のいずれか）。
  final Gem target;
  final List<HandCard> hand;
  final int workers;
  final String? role;

  PlayerState copyWith({List<HandCard>? hand, int? workers}) => PlayerState(
        name: name,
        color: color,
        avatar: avatar,
        target: target,
        image: image,
        role: role,
        hand: hand ?? this.hand,
        workers: workers ?? this.workers,
      );

  /// このプレイヤーの現在の得点（VP）。
  int get score => scoreHand(hand, target);
}

/// 手札とターゲットから得点を計算する（純粋関数・テスト対象）。
///
/// - 黒: 1枚につき -2点
/// - 白: 1枚につき +1点
/// - ターゲットと一致する色: 1枚につき +3点 / 不一致の色: 0点
/// - 黒を除く5色をすべて揃える: +10点
/// - 同じ色を5枚揃える: +20点
/// - 山札の最後の1枚を発掘した札（doubled）は、その札の得点が2倍
int scoreHand(List<HandCard> hand, Gem target) {
  var total = 0;
  final counts = <Gem, int>{};
  for (final card in hand) {
    counts[card.gem] = (counts[card.gem] ?? 0) + 1;
    final base = switch (card.gem) {
      Gem.black => -2,
      Gem.white => 1,
      _ => card.gem == target ? 3 : 0,
    };
    total += card.doubled ? base * 2 : base;
  }

  // 黒を除く5色すべて（白・赤・青・黄・緑）が揃えば +10。
  const colorSet = {Gem.white, Gem.red, Gem.blue, Gem.yellow, Gem.green};
  if (colorSet.every((g) => (counts[g] ?? 0) > 0)) {
    total += 10;
  }

  // いずれかの同色が5枚以上で +20。
  if (counts.values.any((c) => c >= 5)) {
    total += 20;
  }

  return total;
}

enum GamePhase { playing, ended }

@immutable
class GameState {
  const GameState({
    required this.decks,
    required this.players,
    required this.round,
    required this.startPlayer,
    required this.currentPlayer,
    this.phase = GamePhase.playing,
    this.endReason,
    this.log = const [],
  });

  final List<Deck> decks;
  final List<PlayerState> players;
  final int round;
  final int startPlayer;
  final int currentPlayer;
  final GamePhase phase;
  final String? endReason;

  /// 誰が何をしたかの簡易な履歴（新しい順ではなく発生順）。
  final List<String> log;

  bool get isOver => phase == GamePhase.ended;

  GameState copyWith({
    List<Deck>? decks,
    List<PlayerState>? players,
    int? round,
    int? startPlayer,
    int? currentPlayer,
    GamePhase? phase,
    String? endReason,
    List<String>? log,
  }) =>
      GameState(
        decks: decks ?? this.decks,
        players: players ?? this.players,
        round: round ?? this.round,
        startPlayer: startPlayer ?? this.startPlayer,
        currentPlayer: currentPlayer ?? this.currentPlayer,
        phase: phase ?? this.phase,
        endReason: endReason ?? this.endReason,
        log: log ?? this.log,
      );

  /// スコア降順で並べた (プレイヤー, 元インデックス) のランキング。
  List<({PlayerState player, int index})> ranking() {
    final list = [
      for (var i = 0; i < players.length; i++) (player: players[i], index: i),
    ];
    list.sort((a, b) => b.player.score.compareTo(a.player.score));
    return list;
  }
}
