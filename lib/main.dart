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

final selectedActionProvider = StateProvider<int?>((ref) => null);
final selectedDeckProvider = StateProvider<int?>((ref) => null);

/// 手札のおもてを表示中のインデックス（手番が変わるとリセット）。
final revealedHandProvider = StateProvider<Set<int>>((ref) => <int>{});
final memoProvider = StateProvider<String>(
  (ref) => '① 赤 ×　青 ?　黒 ○\n② 赤 ○　青 ?　白 ?\n③ 黄 ?　黒 ○\n④ 青 ?　白 ○',
);

const ink = Color(0xff071117);
const panel = Color(0xff0d1a22);
const gold = Color(0xffc69a45);
const parchment = Color(0xffe5d5ad);
const teal = Color(0xff72e1c1);

/// プレイヤーの立ち絵（画像があれば画像、なければ文字）を丸く表示する。
Widget playerAvatar(PlayerState p, double radius) => CircleAvatar(
      radius: radius,
      backgroundColor: p.color,
      foregroundImage: p.image == null ? null : AssetImage(p.image!),
      child: Text(p.avatar),
    );

/// 画面レイアウト。null（未設定）のときは画面の縦横比から自動判定する。
enum AppLayout { landscape, portrait }

final layoutProvider = StateProvider<AppLayout?>((ref) => null);

/// 明示指定があればそれを、なければ画面比から自動でレイアウトを決める。
AppLayout effectiveLayout(BuildContext context, WidgetRef ref) =>
    ref.watch(layoutProvider) ??
    (MediaQuery.of(context).size.aspectRatio < 1
        ? AppLayout.portrait
        : AppLayout.landscape);

/// 縦・横レイアウトを手動で切り替える（コールバックから呼ぶため watch は使わない）。
void toggleLayout(BuildContext context, WidgetRef ref) {
  final auto = MediaQuery.of(context).size.aspectRatio < 1
      ? AppLayout.portrait
      : AppLayout.landscape;
  final current = ref.read(layoutProvider) ?? auto;
  ref.read(layoutProvider.notifier).state =
      current == AppLayout.portrait ? AppLayout.landscape : AppLayout.portrait;
}

/// ヘッダー右側の操作アイコン（レイアウト切替・手札・ログ・設定）。
List<Widget> headerActions(BuildContext context, WidgetRef ref) {
  final portrait = effectiveLayout(context, ref) == AppLayout.portrait;
  return [
    IconButton(
      tooltip: portrait ? '横レイアウトに切替' : '縦レイアウトに切替',
      onPressed: () => toggleLayout(context, ref),
      icon: Icon(
        portrait ? Icons.stay_current_landscape : Icons.stay_current_portrait,
        color: gold,
      ),
    ),
    IconButton(
      tooltip: 'あなたの手札',
      onPressed: () => showHandSheet(context, ref),
      icon: const Icon(Icons.style, color: gold),
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
  ];
}

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
          fontFamily: 'AppJP',
          useMaterial3: true,
        ),
        routerConfig: ref.watch(routerProvider),
      );
}

/// スクロールなしの一画面レイアウト。
/// ヘッダー / [左パネル | 山札8山 | ターゲット] / 戦略カード の縦3段構成。
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(gameProvider.select((s) => s.isOver), (prev, next) {
      if (next && prev != true) _showResult(context, ref);
    });
    // 手番が変わったら手札のおもて表示をリセットする。
    ref.listen(gameProvider.select((s) => s.currentPlayer), (_, __) {
      ref.read(revealedHandProvider.notifier).state = <int>{};
    });

    final portrait = effectiveLayout(context, ref) == AppLayout.portrait;
    return Scaffold(
      backgroundColor: ink,
      body: SafeArea(
        child:
            portrait ? const PortraitDashboard() : const LandscapeDashboard(),
      ),
    );
  }

  void _showResult(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameProvider);
    const medalColors = [gold, Color(0xffc0c0c0), Color(0xffcd7f32), parchment];
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
                    SizedBox(
                      width: 30,
                      child: Row(
                        children: [
                          if (i < 3)
                            Icon(Icons.emoji_events,
                                size: 18, color: medalColors[i])
                          else
                            const SizedBox(width: 18),
                          Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: parchment,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    playerAvatar(row.player, 14),
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

/// 横（ランドスケープ）レイアウト。横長構成を固定基準サイズで作り、
/// 画面に合わせて等比縮小するので、どの画面でもモック通りの配置を保つ。
class LandscapeDashboard extends StatelessWidget {
  const LandscapeDashboard({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1280,
            height: 840,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Header(),
                  SizedBox(height: 8),
                  Expanded(flex: 55, child: MiddleRow()),
                  SizedBox(height: 8),
                  Expanded(flex: 33, child: StrategySection()),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 縦（ポートレート）レイアウト。上部プレイヤーバー＋
/// 左ステータス｜山札 の中央領域、下部に戦略カード（横スクロール）と自分の手札。
class PortraitDashboard extends ConsumerWidget {
  const PortraitDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      children: [
        PlayerBar(),
        // 盤面（山札）を主役として最大化。戦略カード・手札・ターゲット・メモは
        // 下部バーからモーダルで開く。
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusBar(),
                SizedBox(height: 8),
                BoardPanel(),
              ],
            ),
          ),
        ),
        BottomActionBar(),
      ],
    );
  }
}

/// 下部固定バー。戦略カード・手札・ターゲット・メモをモーダルで開く。
/// 手札は枚数を常時表示（6枚で終了する重要情報のため）。
class BottomActionBar extends ConsumerWidget {
  const BottomActionBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hand = ref.watch(
      gameProvider.select((s) => s.players[s.currentPlayer].hand.length),
    );
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: gold, size: 22),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(color: parchment, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xff050a0d),
        border: Border(top: BorderSide(color: gold)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            item(Icons.style, '戦略カード', () => showStrategySheet(context, ref)),
            item(Icons.back_hand, '手札 $hand/$kHandLimit',
                () => showHandSheet(context, ref)),
            item(Icons.diamond, 'ターゲット', () => showTargetSheet(context, ref)),
            item(Icons.edit_note, 'メモ', () => showMemoSheet(context, ref)),
          ],
        ),
      ),
    );
  }
}

/// 上部の全プレイヤー表示（手番強調・手札/ワーカー枚数）。
class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(gameProvider.select((s) => s.players));
    final current = ref.watch(gameProvider.select((s) => s.currentPlayer));
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff050a0d),
        border: Border.all(color: gold),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          for (var i = 0; i < players.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: PlayerTile(player: players[i], active: current == i),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '表示切替',
            onPressed: () => toggleLayout(context, ref),
            icon: const Icon(Icons.stay_current_landscape, color: gold),
          ),
        ],
      ),
    );
  }
}

/// プレイヤーバー内の1人分（顔・名前・手札・ワーカー・手番バッジ）。
class PlayerTile extends StatelessWidget {
  const PlayerTile({required this.player, required this.active, super.key});
  final PlayerState player;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xff1c2530) : Colors.transparent,
          border: Border.all(
            color: active ? Colors.cyanAccent : Colors.white12,
            width: active ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [BoxShadow(color: Colors.cyanAccent, blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                playerAvatar(player, 18),
                if (active)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '手番',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              '手札 ${player.hand.length}',
              style: const TextStyle(color: parchment, fontSize: 10),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hardware, size: 11, color: gold),
                const SizedBox(width: 2),
                Text(
                  '${player.workers}/${PlayerState.kWorkersPerPlayer}',
                  style: const TextStyle(color: gold, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      );
}

/// 盤面上の自分ステータス横帯（ラウンド・手番・ワーカー・独占・ターゲット）。
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final current = state.players[state.currentPlayer];
    final yourTurn = state.currentPlayer == 0;
    final monopoly = state.decks.indexWhere((d) => d.monopolizedBy != null);
    return GoldPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Text(
            'ラウンド ${state.round}/∞',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: yourTurn ? const Color(0xff123a33) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              yourTurn ? 'あなたの番' : '${current.name}の番',
              style: TextStyle(
                color: yourTurn ? teal : parchment,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.hardware, size: 16, color: gold),
          const SizedBox(width: 3),
          Text(
            '${current.workers}/${PlayerState.kWorkersPerPlayer}',
            style: const TextStyle(color: gold, fontWeight: FontWeight.bold),
          ),
          if (monopoly >= 0) ...[
            const SizedBox(width: 10),
            const Icon(Icons.workspace_premium, size: 16, color: Colors.amber),
            Text('山札${monopoly + 1}',
                style: const TextStyle(color: Colors.amber, fontSize: 12)),
          ],
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'ターゲット',
            onPressed: () => showTargetSheet(context, ref),
            icon: const Icon(Icons.diamond, color: Color(0xff42b9f1), size: 20),
          ),
        ],
      ),
    );
  }
}

/// 中央の山札エリア（主役）。4×2、選択で発光。右上に推理メモボタン。
class BoardPanel extends ConsumerWidget {
  const BoardPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final canDig =
        !state.isOver && state.players[state.currentPlayer].workers > 0;
    return GoldPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '山札エリア（DAIが見える）',
                  style:
                      TextStyle(color: parchment, fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                onTap: () => showMemoSheet(context, ref),
                child: const Row(
                  children: [
                    Icon(Icons.edit_note, size: 18, color: gold),
                    Text('メモ', style: TextStyle(color: gold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.66,
              crossAxisSpacing: 8,
              mainAxisSpacing: 14,
            ),
            itemCount: state.decks.length,
            itemBuilder: (_, i) => DeckCard(
              index: i,
              deck: state.decks[i],
              canDig: canDig,
              dotSize: 18,
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

/// 戦略カードの横スクロール一覧（使用可否を色で区別）。
class StrategyStrip extends StatelessWidget {
  const StrategyStrip({super.key});
  @override
  Widget build(BuildContext context) => GoldPanel(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    '戦略カード（タップして使用）',
                    style: TextStyle(
                        color: parchment, fontWeight: FontWeight.bold),
                  ),
                ),
                Text('横スワイプで一覧 →',
                    style: TextStyle(color: Color(0xff9fb0bf), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: StrategySection.actions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(
                  width: 132,
                  child: ActionCard(index: i, data: StrategySection.actions[i]),
                ),
              ),
            ),
          ],
        ),
      );
}

/// 現在の手番プレイヤーの手札を本人だけが確認するモーダル。
void showHandSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: panel,
    builder: (_) => Consumer(
      builder: (context, ref, __) {
        final state = ref.watch(gameProvider);
        final player = state.players[state.currentPlayer];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${player.name} の手札（本人のみ確認）  現在 ${player.score} 点',
                style: const TextStyle(
                  color: parchment,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (player.hand.isEmpty)
                const Text('まだ宝石がありません。', style: TextStyle(color: parchment))
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final card in player.hand) HandTile(card: card)
                  ],
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

/// ターゲット（宝石）と得点ルールを表示するモーダル。
void showTargetSheet(BuildContext context, WidgetRef ref) {
  final target = ref.read(gameProvider).players[0].target;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: panel,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('あなたのターゲット',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            height: 150,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xff101b23),
              border: Border.all(color: gold, width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: target == Gem.blue
                ? Image.asset('assets/img/gem_blue.png', fit: BoxFit.cover)
                : Center(
                    child: Icon(Icons.diamond, size: 76, color: target.color)),
          ),
          const SizedBox(height: 12),
          Text('${target.label} +3点 / 白 +1点 / 黒 -2点'),
          const Text('黒以外の5色を集めると +10点', style: TextStyle(color: parchment)),
          const Text('同じ色を5枚集めると +20点', style: TextStyle(color: parchment)),
        ],
      ),
    ),
  );
}

/// 推理メモの表示・編集モーダル。
void showMemoSheet(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController(text: ref.read(memoProvider));
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: panel,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('推理メモ（あなただけ）',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              ref.read(memoProvider.notifier).state = controller.text;
              Navigator.pop(ctx);
            },
            child: const Text('保存して閉じる'),
          ),
        ],
      ),
    ),
  );
}

/// 戦略カード一覧をモーダルで開く（横スクロールの一覧を再利用）。
void showStrategySheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: panel,
    builder: (_) => const Padding(
      padding: EdgeInsets.all(12),
      child: StrategyStrip(),
    ),
  );
}

class HandTile extends StatelessWidget {
  const HandTile({required this.card, super.key});
  final HandCard card;
  @override
  Widget build(BuildContext context) => Container(
        width: 58,
        height: 80,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: parchment,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xff695b42), width: 2),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: card.doubled
                  ? const Text(
                      '×2',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    )
                  : const SizedBox(height: 13),
            ),
            Expanded(
              child: Center(
                child: Container(
                  width: 26,
                  height: 26,
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
        ),
      );
}

class Header extends ConsumerWidget {
  const Header({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(gameProvider.select((s) => s.players));
    final current = ref.watch(gameProvider.select((s) => s.currentPlayer));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff050a0d),
        border: Border.all(color: gold),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 168,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FakeDigger',
                  style: TextStyle(
                    color: Color(0xffffd277),
                    fontSize: 26,
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
          Expanded(
            child: Row(
              children: [
                for (var i = 1; i < players.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child:
                          PlayerChip(player: players[i], active: current == i),
                    ),
                  ),
              ],
            ),
          ),
          ...headerActions(context, ref),
        ],
      ),
    );
  }
}

class PlayerChip extends StatelessWidget {
  const PlayerChip({required this.player, this.active = false, super.key});
  final PlayerState player;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
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
                playerAvatar(player, 16),
                if (player.role != null)
                  Positioned(
                    left: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
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
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '手札 ${player.hand.length}枚',
                    style: const TextStyle(color: parchment, fontSize: 12),
                  ),
                ],
              ),
            ),
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

/// ヘッダー下の中央帯：左パネル・山札・右パネル。
class MiddleRow extends StatelessWidget {
  const MiddleRow({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 720;
          final sideWidth = narrow ? 140.0 : 172.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                  width: sideWidth,
                  child: const SidePanel(child: RoundPanel())),
              const SizedBox(width: 8),
              const Expanded(child: MineBoard()),
              const SizedBox(width: 8),
              SizedBox(
                  width: sideWidth + 12,
                  child: const SidePanel(child: TargetPanel())),
            ],
          );
        },
      );
}

/// 中身が縦に収まらない場合は縮小し、常にスクロールなしで収める枠。
class SidePanel extends StatelessWidget {
  const SidePanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => GoldPanel(
        padding: const EdgeInsets.all(10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 150,
            child: child,
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ラウンド  ${state.round} / ∞',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const Divider(color: gold),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: yourTurn ? const Color(0xff123a33) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            yourTurn ? 'あなたの番です' : '${current.name} の番',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: yourTurn ? teal : parchment,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('スタートプレイヤー'),
        const SizedBox(height: 6),
        Row(
          children: [
            playerAvatar(start, 20),
            const SizedBox(width: 8),
            Text(start.name),
          ],
        ),
        const Divider(height: 26),
        Text('ワーカー（${current.name}）'),
        const SizedBox(height: 6),
        current.workers > 0
            ? Row(
                children: [
                  for (var i = 0; i < current.workers; i++)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.hardware, size: 26, color: gold),
                    ),
                ],
              )
            : const Text('（なし）', style: TextStyle(color: parchment)),
        const Divider(height: 26),
        const Text('独占チップ'),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.workspace_premium, size: 26, color: Colors.amber),
        ),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: () {}, child: const Text('?  DAI早見表')),
      ],
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
    Widget cell(int i) => Padding(
          padding: const EdgeInsets.all(6),
          child: DeckCard(
            index: i,
            deck: state.decks[i],
            canDig: canDig,
            crownColor: state.decks[i].monopolizedBy == null
                ? null
                : state.players[state.decks[i].monopolizedBy!].color,
          ),
        );
    return GoldPanel(
      child: Column(
        children: [
          const Text(
            '—  山札エリア（DAIが見える） —',
            style: TextStyle(color: parchment, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++) Expanded(child: cell(i))
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 4; i < 8; i++) Expanded(child: cell(i))
                    ],
                  ),
                ),
              ],
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
    this.dotSize = 15,
    super.key,
  });
  final int index;
  final Deck deck;
  final bool canDig;
  final Color? crownColor;
  final double dotSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = canDig && !deck.isEmpty;
    final selected = ref.watch(selectedDeckProvider) == index;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '山札${index + 1}、${deck.count}枚',
      child: InkWell(
        onTap: enabled
            ? () {
                ref.read(selectedDeckProvider.notifier).state = index;
                ref.read(gameProvider.notifier).dig(index);
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: deck.isEmpty ? const Color(0xff9a8f77) : parchment,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selected
                      ? Colors.cyanAccent
                      : (enabled ? const Color(0xff695b42) : Colors.black26),
                  width: selected ? 3 : 2,
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(color: Colors.cyanAccent, blurRadius: 12)
                      ]
                    : const [BoxShadow(color: Colors.black87, blurRadius: 4)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: const Color(0xff6a5e49),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  const Divider(color: Color(0xff8a7754), height: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Wrap(
                        spacing: 3,
                        runSpacing: 3,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final gem in deck.cards)
                            Container(
                              width: dotSize,
                              height: dotSize,
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
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '残り ${deck.count}枚',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (crownColor != null)
              Positioned(
                right: -6,
                top: -12,
                child:
                    Icon(Icons.workspace_premium, size: 26, color: crownColor),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'あなたのターゲット',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          height: 120,
          width: 100,
          decoration: BoxDecoration(
            color: const Color(0xff101b23),
            border: Border.all(color: gold, width: 4),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: target == Gem.blue
              ? Image.asset('assets/img/gem_blue.png', fit: BoxFit.cover)
              : Center(
                  child: Icon(Icons.diamond, size: 60, color: target.color)),
        ),
        const SizedBox(height: 8),
        Text('${target.label} +3点 / 白 +1点 / 黒 -2点',
            textAlign: TextAlign.center),
        const Text('5色集めると +10点', style: TextStyle(color: parchment)),
        const Divider(height: 22, color: gold),
        const Text(
          '推理メモ（あなただけ）',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(ref.watch(memoProvider), style: const TextStyle(height: 1.6)),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => _editMemo(context, ref),
          child: const Text('メモを編集'),
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

class ActionData {
  const ActionData(
      this.title, this.icon, this.cost, this.description, this.image);
  final String title, description, image;
  final IconData icon;
  final int cost;
}

class StrategySection extends StatelessWidget {
  const StrategySection({super.key});
  static const actions = [
    ActionData(
        '発掘', Icons.hardware, 1, '山札の1番上のカードを手札に加える', 'assets/img/act_dig.png'),
    ActionData('鑑定', Icons.search, 1, '他プレイヤーの宝石カード1枚を見る',
        'assets/img/act_appraise.png'),
    ActionData('調査', Icons.visibility, 1, '任意の山札のすべてのカードを見る',
        'assets/img/act_investigate.png'),
    ActionData('整地', Icons.grass, 1, '任意の山札2つを1〜5枚ずつに作り変える',
        'assets/img/act_level.png'),
    ActionData(
        '埋葬', Icons.south, 1, '手札のカード1枚を山札の1番上に置く', 'assets/img/act_bury.png'),
    ActionData('強奪', Icons.pan_tool, 2, '他プレイヤーの宝石を自分の手札にする',
        'assets/img/act_rob.png'),
    ActionData('独占', Icons.workspace_premium, 1, '任意の山札を効果の対象外にする',
        'assets/img/act_monopoly.png'),
    ActionData('捏造', Icons.swap_horiz, 2, '手札と山札のカードを交換する',
        'assets/img/act_fabricate.png'),
    ActionData('保護', Icons.shield, 1, '手札を任意の枚数、効果対象外にする',
        'assets/img/act_protect.png'),
    ActionData('取引', Icons.handshake, 2, '他プレイヤーとカードを1枚ずつ交換',
        'assets/img/act_trade.png'),
  ];
  @override
  Widget build(BuildContext context) => GoldPanel(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Text(
              '—  戦略カード（ワーカーを置いて効果を使用 / 現在は発掘のみ実装） —',
              style: TextStyle(color: parchment, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Column(
                children: [
                  for (var row = 0; row < 2; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < 5; col++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: ActionCard(
                                  index: row * 5 + col,
                                  data: actions[row * 5 + col],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
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

  /// 現状は「発掘」のみ実装済み。それ以外は準備中。
  bool get _implemented => data.title == '発掘';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedActionProvider) == index;
    final usable = _implemented;
    return Semantics(
      button: true,
      enabled: usable,
      selected: selected,
      child: InkWell(
        onTap: usable
            ? () => ref.read(selectedActionProvider.notifier).state = index
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // 使用可能は中明度、準備中は暗く沈める。
            color: usable ? const Color(0xff16303b) : const Color(0xff0b141a),
            border: Border.all(
              color: selected
                  ? Colors.cyanAccent
                  : (usable ? gold : Colors.white24),
              width: selected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? const [BoxShadow(color: Colors.cyanAccent, blurRadius: 10)]
                : null,
          ),
          child: Opacity(
            opacity: usable ? 1 : 0.5,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: ink,
                      child: Text(
                        '${data.cost}',
                        style: const TextStyle(
                          color: gold,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Image.asset(data.image, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Text(
                  usable ? data.description : '準備中',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.3,
                    fontSize: 11,
                    color: usable ? Colors.white : gold,
                    fontWeight: usable ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
