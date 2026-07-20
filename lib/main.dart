import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'game/game_controller.dart';
import 'game/models.dart';

void main() => runApp(const ProviderScope(child: FakeDiggerApp()));

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, __) => const GameScreen())],
  ),
);

/// 手札のおもてを表示しているインデックス（手番が変わるとリセット）。
final revealedHandProvider = StateProvider<Set<int>>((ref) => <int>{});
final selectedActionProvider = StateProvider<int?>((ref) => null);
final memoProvider = StateProvider<String>(
  (ref) => '① 赤 ×　青 ?　黒 ○\n② 赤 ○　青 ?　白 ?\n③ 黄 ?　黒 ○\n④ 青 ?　白 ○',
);

const ink = Color(0xff071117);
const panel = Color(0xff0d1a22);
const gold = Color(0xffc69a45);
const parchment = Color(0xffe5d5ad);
const teal = Color(0xff72e1c1);

class FakeDiggerApp extends ConsumerWidget {
  const FakeDiggerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'FakeDigger',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: ColorScheme.fromSeed(
            seedColor: gold,
            brightness: Brightness.dark,
          ),
          fontFamily: 'serif',
          useMaterial3: true,
        ),
        routerConfig: ref.watch(routerProvider),
      );
}

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 手番が変わったら手札のおもて表示をリセットする。
    ref.listen(gameProvider.select((s) => s.currentPlayer), (_, __) {
      ref.read(revealedHandProvider.notifier).state = <int>{};
    });
    // ゲーム終了時に結果ダイアログを表示する。
    ref.listen(gameProvider.select((s) => s.isOver), (prev, next) {
      if (next && prev != true) _showResult(context, ref);
    });

    final state = ref.watch(gameProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 900;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: Header(state: state)),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverToBoxAdapter(
                    child: compact
                        ? const Column(
                            children: [
                              RoundPanel(),
                              SizedBox(height: 12),
                              MineBoard(),
                              SizedBox(height: 12),
                              TargetPanel(),
                            ],
                          )
                        : const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 165, child: RoundPanel()),
                              SizedBox(width: 12),
                              Expanded(child: MineBoard()),
                              SizedBox(width: 12),
                              SizedBox(width: 180, child: TargetPanel()),
                            ],
                          ),
                  ),
                ),
                const SliverToBoxAdapter(child: HandSection()),
                const SliverToBoxAdapter(child: StrategySection()),
                const SliverToBoxAdapter(child: HelpSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showResult(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameProvider);
    const medals = ['🥇', '🥈', '🥉', '4'];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: panel,
        title: const Text('ゲーム終了（得点結果）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.endReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.endReason!,
                  style: const TextStyle(color: parchment, fontSize: 13),
                ),
              ),
            for (final (i, row) in state.ranking().indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text(medals[i])),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: row.player.color,
                      child: Text(
                        row.player.avatar,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.player.name)),
                    Text(
                      '${row.player.score} 点',
                      style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              ref.read(gameProvider.notifier).reset();
              Navigator.pop(context);
            },
            child: const Text('もう一度あそぶ'),
          ),
        ],
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({required this.state, super.key});
  final GameState state;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xff050a0d),
          border: Border(bottom: BorderSide(color: gold)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 8,
          children: [
            const SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FakeDigger',
                    style: TextStyle(
                      color: Color(0xffffd277),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'フェイクディガー',
                    style: TextStyle(color: parchment, fontSize: 11),
                  ),
                ],
              ),
            ),
            // 対戦相手（あなた以外）のチップを表示する。
            for (var i = 1; i < state.players.length; i++)
              PlayerChip(
                player: state.players[i],
                active: state.currentPlayer == i,
              ),
            const IconButton(
              tooltip: 'ログ',
              onPressed: null,
              icon: Icon(Icons.receipt_long, color: gold),
            ),
            const IconButton(
              tooltip: '設定',
              onPressed: null,
              icon: Icon(Icons.settings, color: gold),
            ),
          ],
        ),
      );
}

class PlayerChip extends StatelessWidget {
  const PlayerChip({required this.player, this.active = false, super.key});
  final PlayerState player;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
        width: 205,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: panel,
          border: Border.all(
            color: active ? Colors.cyanAccent : gold,
            width: active ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor: player.color,
                  child: Text(player.avatar),
                ),
                if (player.role != null)
                  Positioned(
                    left: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: ink,
                        border: Border.all(color: gold),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        player.role!,
                        style: const TextStyle(
                          color: gold,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '手札 ${player.hand.length}枚',
                    style: const TextStyle(color: parchment),
                  ),
                ],
              ),
            ),
            const Icon(Icons.style, color: Color(0xff7187a3)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: ink,
                border: Border.all(color: gold),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'VP ${player.score}',
                style: const TextStyle(
                  color: gold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
}

class GoldPanel extends StatelessWidget {
  const GoldPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: panel,
          border: Border.all(color: gold),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        child: child,
      );
}

class RoundPanel extends ConsumerWidget {
  const RoundPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final current = state.players[state.currentPlayer];
    final start = state.players[state.startPlayer];
    final yourTurn = state.currentPlayer == 0;
    return GoldPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ラウンド  ${state.round} / ∞',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Divider(color: gold),
          Text(
            yourTurn ? 'あなたの番です' : '${current.name} の番',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: yourTurn ? teal : parchment,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text('スタートプレイヤー'),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: start.color,
                child: Text(start.avatar),
              ),
              const SizedBox(width: 8),
              Text(start.name),
            ],
          ),
          const Divider(height: 30),
          Text('ワーカー（${current.name}）'),
          const SizedBox(height: 8),
          Text(
            current.workers > 0 ? '⛏   ' * current.workers : '（なし）',
            style: const TextStyle(fontSize: 28, color: gold),
          ),
          const Divider(height: 30),
          const Text('独占チップ'),
          const Text('♛', style: TextStyle(fontSize: 28, color: Colors.amber)),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: () {}, child: const Text('?  DAI早見表')),
        ],
      ),
    );
  }
}

class MineBoard extends ConsumerWidget {
  const MineBoard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final canDig =
        !state.isOver && state.players[state.currentPlayer].workers > 0;
    return GoldPanel(
      child: Column(
        children: [
          const Text(
            '—  山札エリア（DAIが見える） —',
            style: TextStyle(color: parchment, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            canDig ? 'タップで発掘（1番上の宝石を手札へ）' : 'ゲーム終了',
            style: const TextStyle(color: Color(0xff9fb0bf), fontSize: 12),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 155,
              childAspectRatio: .72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 18,
            ),
            itemCount: state.decks.length,
            itemBuilder: (_, i) => DeckCard(
              index: i,
              deck: state.decks[i],
              canDig: canDig,
              crownColor: state.decks[i].monopolizedBy == null
                  ? null
                  : state.players[state.decks[i].monopolizedBy!].color,
            ),
          ),
        ],
      ),
    );
  }
}

class DeckCard extends ConsumerWidget {
  const DeckCard({
    required this.index,
    required this.deck,
    required this.canDig,
    this.crownColor,
    super.key,
  });
  final int index;
  final Deck deck;
  final bool canDig;
  final Color? crownColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = canDig && !deck.isEmpty;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '山札${index + 1}、${deck.count}枚',
      child: InkWell(
        onTap:
            enabled ? () => ref.read(gameProvider.notifier).dig(index) : null,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 6,
              right: -6,
              top: 10,
              bottom: -8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xff766b59),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.black),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: deck.isEmpty ? const Color(0xff9a8f77) : parchment,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: enabled ? const Color(0xff695b42) : Colors.black26,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 6)
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xff6a5e49),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  const Divider(color: Color(0xff8a7754)),
                  Expanded(
                    child: Center(
                      child: Wrap(
                        spacing: 3,
                        runSpacing: 3,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final gem in deck.cards)
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: gem.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${deck.count}枚',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (crownColor != null)
              Positioned(
                right: -7,
                top: -16,
                child: Text(
                  '♛',
                  style: TextStyle(fontSize: 36, color: crownColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TargetPanel extends ConsumerWidget {
  const TargetPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(gameProvider.select((s) => s.players[0].target));
    return Column(
      children: [
        GoldPanel(
          child: Column(
            children: [
              const Text(
                'あなたのターゲット',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                width: 120,
                decoration: BoxDecoration(
                  color: const Color(0xff101b23),
                  border: Border.all(color: gold, width: 4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.diamond, size: 76, color: target.color),
                ),
              ),
              const SizedBox(height: 10),
              Text('${target.label} +3点 / 白 +1点 / 黒 -2点'),
              const Text('5色集めると +10点', style: TextStyle(color: parchment)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GoldPanel(
          child: Column(
            children: [
              const Text(
                '推理メモ（あなただけ）',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(ref.watch(memoProvider),
                  style: const TextStyle(height: 1.7)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _editMemo(context, ref),
                child: const Text('メモを編集'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editMemo(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(memoProvider));
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('推理メモ'),
        content:
            TextField(controller: controller, maxLines: 6, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(memoProvider.notifier).state = controller.text;
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class HandSection extends ConsumerWidget {
  const HandSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final player = state.players[state.currentPlayer];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GoldPanel(
        child: Column(
          children: [
            Text(
              '—  ${player.name} の手札（本人のみ確認） —',
              style: const TextStyle(
                  color: parchment, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'タップでおもてを確認 / もう一度タップで裏に戻す',
              style: TextStyle(color: Color(0xff9fb0bf), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (player.hand.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'まだ宝石がありません。山札を発掘しましょう。',
                  style: TextStyle(color: parchment),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < player.hand.length; i++)
                    HandCardTile(index: i, card: player.hand[i]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class HandCardTile extends ConsumerWidget {
  const HandCardTile({required this.index, required this.card, super.key});
  final int index;
  final HandCard card;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revealed = ref.watch(revealedHandProvider).contains(index);
    return Semantics(
      button: true,
      label: '手札${index + 1}',
      child: InkWell(
        onTap: () {
          final set = {...ref.read(revealedHandProvider)};
          set.contains(index) ? set.remove(index) : set.add(index);
          ref.read(revealedHandProvider.notifier).state = set;
        },
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 66,
          height: 92,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: revealed ? parchment : const Color(0xff10151d),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xff695b42), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 5)],
          ),
          child: revealed
              ? Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: card.doubled
                          ? const Text(
                              '×2',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            )
                          : const SizedBox(height: 14),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: card.gem.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      card.gem.label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: gold,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class ActionData {
  const ActionData(this.title, this.icon, this.cost, this.description);
  final String title, icon, description;
  final int cost;
}

class StrategySection extends StatelessWidget {
  const StrategySection({super.key});
  static const actions = [
    ActionData('発掘', '⛏', 1, '山札の1番上のカードを\n手札に加える'),
    ActionData('鑑定', '⌕', 1, '他プレイヤーの\n宝石カード1枚を見る'),
    ActionData('調査', '🏮', 1, '任意の山札にある\nすべてのカードを見る'),
    ActionData('整地', '♠', 1, '任意の山札2つを混ぜ、\n1〜5枚ずつに作り変える'),
    ActionData('埋葬', '♤', 1, '手札のカード1枚を\n任意の山札の上に置く'),
    ActionData('強奪', '🥷', 2, '他プレイヤーの宝石を\n自分の手札にする'),
    ActionData('独占', '♛', 1, '任意の山札を\n効果の対象外にする'),
    ActionData('捏造', '↔', 2, '手札と山札のカードを\n交換する'),
    ActionData('保護', '🛡', 1, '手札を任意の枚数\n効果対象外にする'),
    ActionData('取引', '🤝', 2, '他プレイヤーと\nカードを1枚ずつ交換'),
  ];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                '—  戦略カード（現在は「発掘」のみ実装） —',
                style: TextStyle(color: parchment, fontWeight: FontWeight.bold),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: box.maxWidth > 900
                      ? 5
                      : box.maxWidth > 520
                          ? 3
                          : 2,
                  childAspectRatio: .82,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: actions.length,
                itemBuilder: (_, i) => ActionCard(index: i, data: actions[i]),
              ),
            ),
          ],
        ),
      );
}

class ActionCard extends ConsumerWidget {
  const ActionCard({required this.index, required this.data, super.key});
  final int index;
  final ActionData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedActionProvider) == index;
    // 現状は「発掘」のみ実装済み。それ以外は説明表示のみ。
    final implemented = data.title == '発掘';
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => ref.read(selectedActionProvider.notifier).state = index,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: panel,
            border: Border.all(
              color: selected ? Colors.cyanAccent : gold,
              width: selected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Opacity(
            opacity: implemented ? 1 : 0.55,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: ink,
                      child: Text(
                        '${data.cost}',
                        style: const TextStyle(color: gold),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child:
                        Text(data.icon, style: const TextStyle(fontSize: 48)),
                  ),
                ),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, box) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: box.maxWidth > 900 ? 3 : 1,
            childAspectRatio: box.maxWidth > 900 ? 2.0 : 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: const [
              HelpCard(title: '発掘の流れ', steps: ['山札を選択', '発掘しますか？', '宝石を獲得']),
              HelpCard(title: '鑑定の流れ', steps: ['相手の手札', 'カードを選ぶ', '自分だけ確認']),
              HelpCard(title: '埋葬・捏造', steps: ['手札を選択', 'ドラッグ', '山札へ置く']),
              HelpCard(title: '調査の流れ', steps: ['山札を選択', '中身を確認', '元に戻る']),
              HelpCard(
                  title: '手札エリア', steps: ['🔴 3', '⚪ 1', '⚫ 12', '🔵 3', '?']),
              HelpCard(
                title: '得点計算',
                steps: ['ターゲット +3', '白 +1 / 黒 -2', '5色 +10'],
              ),
              HelpCard(title: '保護されたカード', steps: ['🔴 6', '🔒 裏', '🟡 3']),
              HelpCard(title: '独占の表示', steps: ['③ 青の王冠', '⑧ 赤の王冠']),
            ],
          ),
        ),
      );
}

class HelpCard extends StatelessWidget {
  const HelpCard({required this.title, required this.steps, super.key});
  final String title;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => GoldPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(color: gold),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Flexible(
                      child: Text(
                        steps[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: parchment),
                      ),
                    ),
                    if (i < steps.length - 1)
                      const Icon(Icons.arrow_forward, color: gold),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
