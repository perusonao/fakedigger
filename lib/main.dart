import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'game/game_controller.dart';
import 'game/models.dart';
import 'gem_icon.dart';
import 'theme.dart';

void main() => runApp(const ProviderScope(child: FakeDiggerApp()));

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, __) => const GameScreen())],
  ),
);

/// 選択中の戦略カード（`kStrategyActions`のインデックス）。
final selectedActionProvider = StateProvider<int?>((ref) => null);

/// 選択中の山札（インデックス）。
final selectedDeckProvider = StateProvider<int?>((ref) => null);

/// 選択中の自分の手札カード（インデックス）。今後、手札を対象に取る
/// 戦略（埋葬・捏造・取引など）を実装する際に使う。
final selectedHandCardProvider = StateProvider<int?>((ref) => null);

/// 手札表示エリアに表示するプレイヤー（既定は自分＝index 0）。
/// プレイヤー表示エリアのアイコンをタップすると切り替わる。
final selectedPlayerProvider = StateProvider<int>((ref) => 0);

final memoProvider = StateProvider<String>(
  (ref) => '① 赤 ×　青 ?　黒 ○\n② 赤 ○　青 ?　白 ?\n③ 黄 ?　黒 ○\n④ 青 ?　白 ○',
);

/// SnackBarを表示するための、Scaffoldツリーに依存しないグローバルキー。
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// プレイヤー一覧の先頭（index 0）が、このデバイスを操作する「自分」。
bool isSelf(int index) => index == 0;

/// プレイヤーの立ち絵（画像があれば画像、なければ文字）を丸く表示する。
Widget playerAvatar(PlayerState p, double radius) => CircleAvatar(
      radius: radius,
      backgroundColor: p.color,
      foregroundImage: p.image == null ? null : AssetImage(p.image!),
      child: Text(p.avatar),
    );

class FakeDiggerApp extends ConsumerWidget {
  const FakeDiggerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'FakeDigger',
        theme: buildAppTheme(),
        routerConfig: ref.watch(routerProvider),
      );
}

/// スマホ縦画面向けのゲームプレイ画面。
///
/// 上から「上部ステータスバー／山札エリア／戦略カードエリア／
/// プレイヤー表示エリア／自分の手札エリア／下部固定ナビゲーション」の
/// 6ブロック構成（[Dashboard]）。タブレットやWebの広い画面では
/// 中央寄せ・最大幅で表示する。
///
/// 手番の進行もこのウィジェットが司る。手番が変わるたびに選択状態を
/// リセットし、CPU（自分以外）の手番なら少し待ってから山札を強調表示し、
/// 発掘して結果を裏向きで告知する。
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleTurn(ref.read(gameProvider).currentPlayer);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameProvider.select((s) => s.isOver), (prev, next) {
      if (next && prev != true) _showResult(context, ref);
    });
    ref.listen(gameProvider.select((s) => s.currentPlayer), (_, next) {
      _handleTurn(next);
    });

    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: const Dashboard(),
          ),
        ),
      ),
    );
  }

  /// 手番が変わるたびに選択状態をリセットする。CPU（自分以外）の手番なら
  /// 自動進行を開始する。自分の手番は盤面の操作をそのまま待てばよい。
  void _handleTurn(int player) {
    if (ref.read(gameProvider).isOver) return;
    ref.read(selectedActionProvider.notifier).state = null;
    ref.read(selectedDeckProvider.notifier).state = null;
    ref.read(selectedHandCardProvider.notifier).state = null;
    if (!isSelf(player)) _runCpuTurn(player);
  }

  /// CPUの手番：山札を強調 → 発掘 → 裏向きで告知（手札に加わるのは dig() 側）。
  Future<void> _runCpuTurn(int player) async {
    await Future.delayed(kCpuThinkDelay);
    if (!mounted) return;
    final controller = ref.read(gameProvider.notifier);
    var state = ref.read(gameProvider);
    if (state.isOver || state.currentPlayer != player) return;
    final deckIndex = controller.pickCpuDeck();
    if (deckIndex == null) return;

    ref.read(selectedDeckProvider.notifier).state = deckIndex;
    await Future.delayed(kCpuHighlightDelay);
    if (!mounted) return;
    state = ref.read(gameProvider);
    if (state.isOver || state.currentPlayer != player) return;

    final name = state.players[player].name;
    controller.dig(deckIndex);
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
        backgroundColor: kPanel,
        content: Row(
          children: [
            const Icon(Icons.diamond, color: kGold, size: 20),
            const SizedBox(width: 10),
            Text('$nameは『発掘』しました', style: const TextStyle(color: kBeige)),
          ],
        ),
      ),
    );
  }

  void _showResult(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameProvider);
    const medalColors = [kGold, Color(0xffc0c0c0), Color(0xffcd7f32), kBeige];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('ゲーム終了（得点結果）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.endReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.endReason!,
                  style: const TextStyle(color: kBeige, fontSize: 13),
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
                              color: kBeige,
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
                        color: kGold,
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

/// 6ブロックの一画面ダッシュボード。上部ステータスバーと下部ナビゲーションを
/// 固定し、その間（山札・戦略カード・プレイヤー・自分の手札）はスクロール
/// させず、画面の高さに合わせて配分（[Expanded]の比率）して1画面に収める。
class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const StatusBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(flex: 6, child: DeckArea()),
                  SizedBox(height: 6),
                  Expanded(flex: 4, child: StrategyArea()),
                  SizedBox(height: 6),
                  Expanded(flex: 2, child: PlayerArea()),
                  SizedBox(height: 6),
                  Expanded(flex: 3, child: HandArea()),
                ],
              ),
            ),
          ),
          const BottomNav(),
        ],
      );
}

/// 1. 上部ステータスバー：メニュー・ラウンド・手番状態・ワーカー数・
/// 推理メモ／ログボタン。ターゲット・手札枚数・プレイヤー名はここに置かない
/// （プレイヤー表示エリアと重複させない）。
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final current = state.players[state.currentPlayer];
    final yourTurn = state.currentPlayer == 0;
    final awaitingDeck = yourTurn &&
        ref.watch(selectedActionProvider) != null &&
        ref.watch(selectedDeckProvider) == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(bottom: BorderSide(color: kGold)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'メニュー',
              onPressed: () => showMenuSheet(context, ref),
              icon: const Icon(Icons.menu, color: kBeige, size: 20),
            ),
            Text(
              'ラウンド ${state.round}/∞',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: yourTurn ? kSelfTurn : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        !yourTurn
                            ? '${current.name}の番'
                            : (awaitingDeck ? '発掘する山を選択' : 'あなたの番'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: yourTurn ? Colors.white : kBeige,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (!yourTurn) ...[
                      const SizedBox(width: 4),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kBeige,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.hardware, size: 15, color: kGold),
            const SizedBox(width: 2),
            Text(
              '${current.workers}/${PlayerState.kWorkersPerPlayer}',
              style: const TextStyle(
                  color: kGold, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '推理メモ',
              onPressed: () => showMemoSheet(context, ref),
              icon: const Icon(Icons.edit_note, color: kBeige, size: 20),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'ログ',
              onPressed: () => showLogSheet(context, ref),
              icon: const Icon(Icons.forum, color: kBeige, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. 山札エリア：8つの山札を4列×2段（幅が狭い場合は2列×4段）で表示する。
class DeckArea extends ConsumerWidget {
  const DeckArea({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    // 自分の手番で、ワーカーが残っているあいだだけ山札を選べる。
    final canSelect = !state.isOver &&
        state.currentPlayer == 0 &&
        state.players[0].workers > 0;
    return GoldPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '山札エリア（DAIが見える・タップで選択・長押しで詳細）',
            style: TextStyle(
                color: kBeige, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 幅320px想定など、狭い画面では2列×4段に切り替える。
                final narrow = constraints.maxWidth < 340;
                final cols = narrow ? 2 : 4;
                final rows = narrow ? 4 : 2;
                const crossSpacing = 6.0;
                const mainSpacing = 6.0;
                final itemWidth =
                    (constraints.maxWidth - crossSpacing * (cols - 1)) / cols;
                final itemHeight =
                    (constraints.maxHeight - mainSpacing * (rows - 1)) / rows;
                final ratio = itemWidth / itemHeight;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: ratio,
                    crossAxisSpacing: crossSpacing,
                    mainAxisSpacing: mainSpacing,
                  ),
                  itemCount: state.decks.length,
                  itemBuilder: (_, i) => DeckCard(
                    index: i,
                    deck: state.decks[i],
                    canSelect: canSelect,
                    crownColor: state.decks[i].monopolizedBy == null
                        ? null
                        : (state.decks[i].monopolizedBy == 0
                            ? kSelected
                            : kDanger),
                  ),
                );
              },
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
    required this.canSelect,
    this.crownColor,
    super.key,
  });
  final int index;
  final Deck deck;
  final bool canSelect;
  final Color? crownColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = canSelect && !deck.isEmpty;
    final selected = ref.watch(selectedDeckProvider) == index;
    // DAIの色ヒント（先頭から最大3枚）。完全な内訳は長押しの詳細で見せる。
    final hints = deck.cards.take(3).toList();
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '山札${index + 1}、${deck.count}枚',
      child: GestureDetector(
        onLongPress: () => showDeckDetailDialog(context, ref, index),
        child: InkWell(
          onTap: enabled ? () => onDeckTap(context, ref, index) : null,
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 背面に2枚重ねて、山札らしい厚みを出す。
              if (!deck.isEmpty)
                for (var i = 2; i >= 1; i--)
                  Positioned(
                    left: i * 3.0,
                    top: i * 3.0,
                    right: -i * 3.0,
                    bottom: -i * 3.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kBeige.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: const Color(0xff9a8a63), width: 1.4),
                      ),
                    ),
                  ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: deck.isEmpty ? const Color(0xffcfc6ac) : kBeige,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected
                        ? kSelected
                        : (enabled ? const Color(0xff8a6d3c) : Colors.black26),
                    width: selected ? 3 : 2,
                  ),
                  boxShadow: selected
                      ? const [BoxShadow(color: kSelected, blurRadius: 12)]
                      : const [BoxShadow(color: Colors.black87, blurRadius: 4)],
                ),
                // 計算した比率のセルに収まらない場合でも、はみ出さず
                // 自動で縮小されるようFittedBoxで包む（Expandedは使わない）。
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: const Color(0xff6a5e49),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: deck.isEmpty
                              ? const Icon(Icons.remove_circle_outline,
                                  color: Colors.black26, size: 28)
                              : GemIcon(gem: deck.top, size: 34),
                        ),
                      ),
                      if (!deck.isEmpty) ...[
                        Wrap(
                          spacing: 3,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final g in hints)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: g.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black45, width: 0.6),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        '残り${deck.count}枚',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (crownColor != null)
                Positioned(
                  right: -6,
                  top: -10,
                  child: Icon(Icons.workspace_premium,
                      size: 24, color: crownColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 山札をタップしたときの処理。まず選択状態にし、すでに「発掘」が
/// 選択されていれば続けて確認ダイアログを出す。
void onDeckTap(BuildContext context, WidgetRef ref, int index) {
  if (ref.read(gameProvider).decks[index].isEmpty) return;
  ref.read(selectedDeckProvider.notifier).state = index;
  maybeConfirmDig(context, ref, index);
}

/// 「発掘」が選択済みで、かつ発掘可能な状況なら確認ダイアログを出す。
void maybeConfirmDig(BuildContext context, WidgetRef ref, int deckIndex) {
  final state = ref.read(gameProvider);
  if (state.isOver ||
      state.currentPlayer != 0 ||
      state.players[0].workers <= 0) {
    return;
  }
  final actionIndex = ref.read(selectedActionProvider);
  if (actionIndex == null) return;
  if (kStrategyActions[actionIndex].title != '発掘') return;
  confirmAndDig(context, ref, deckIndex);
}

/// 山札を長押ししたときの詳細ダイアログ（山札番号・残り枚数・DAI・独占者）。
void showDeckDetailDialog(BuildContext context, WidgetRef ref, int index) {
  final state = ref.read(gameProvider);
  final deck = state.decks[index];
  final monopolizedName = deck.monopolizedBy == null
      ? 'なし'
      : state.players[deck.monopolizedBy!].name;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kPanel,
      title: Text('山札${index + 1}の詳細'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('残り枚数：${deck.count}枚', style: const TextStyle(color: kBeige)),
          const SizedBox(height: 10),
          const Text('DAI',
              style: TextStyle(color: kBeige, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (deck.isEmpty)
            const Text('（山札は空です）', style: TextStyle(color: kBeige))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final g in deck.cards) GemIcon(gem: g, size: 22)],
            ),
          const SizedBox(height: 10),
          Text('独占者：$monopolizedName', style: const TextStyle(color: kBeige)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('閉じる'),
        ),
        FilledButton(
          onPressed: deck.isEmpty
              ? null
              : () {
                  Navigator.pop(ctx);
                  onDeckTap(context, ref, index);
                },
          child: const Text('この山札を選択'),
        ),
      ],
    ),
  );
}

/// 山札をタップ→（「発掘」選択済みなら）確認ダイアログ→（YES）発掘した宝石を
/// おもてで告知→手札に加わる。（NO）なら何も起きず、選び直せる。
Future<void> confirmAndDig(
  BuildContext context,
  WidgetRef ref,
  int index,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kPanel,
      title: const Text('発掘'),
      content: Text('この山（山札${index + 1}）を『発掘』しますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('やめる'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('発掘する'),
        ),
      ],
    ),
  );
  if (ok != true) return;

  ref.read(selectedDeckProvider.notifier).state = index;
  ref.read(gameProvider.notifier).dig(index);
  ref.read(selectedActionProvider.notifier).state = null;

  final card = ref.read(gameProvider).players[0].hand.last;
  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 1400),
      backgroundColor: kPanel,
      content: Row(
        children: [
          GemIcon(gem: card.gem, size: 22),
          const SizedBox(width: 10),
          Text('${card.gem.label}の宝石を発掘しました！',
              style: const TextStyle(color: kBeige)),
        ],
      ),
    ),
  );
}

/// 3. 戦略カードエリア：横スクロール＋ページインジケーター。
class StrategyArea extends ConsumerStatefulWidget {
  const StrategyArea({super.key});
  @override
  ConsumerState<StrategyArea> createState() => _StrategyAreaState();
}

class _StrategyAreaState extends ConsumerState<StrategyArea> {
  final _controller = ScrollController();
  int _page = 0;
  int _pageCount = 1;

  static const _cardWidth = 132.0;
  static const _spacing = 8.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients || _pageCount <= 1) return;
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) return;
    final page = (_controller.offset / max * (_pageCount - 1))
        .round()
        .clamp(0, _pageCount - 1);
    if (page != _page) setState(() => _page = page);
  }

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
                    '戦略カード（ワーカーを置いて使用）',
                    style: TextStyle(
                        color: kBeige,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                Icon(Icons.swipe, size: 14, color: kGold),
                SizedBox(width: 4),
                Text('横にスワイプ', style: TextStyle(color: kGold, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final visible = ((constraints.maxWidth + _spacing) /
                          (_cardWidth + _spacing))
                      .floor()
                      .clamp(1, kStrategyActions.length);
                  final pageCount = (kStrategyActions.length / visible).ceil();
                  if (pageCount != _pageCount) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _pageCount = pageCount);
                    });
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          itemCount: kStrategyActions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: _spacing),
                          itemBuilder: (_, i) => SizedBox(
                            width: _cardWidth,
                            child:
                                ActionCard(index: i, data: kStrategyActions[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < pageCount; i++)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page ? kSelected : Colors.white24,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

/// 戦略カードの状態。全戦略で共通のモデルを使う
/// （現状「発掘」以外は `comingSoon` 固定）。
enum ActionState { usable, selected, used, insufficientWorkers, comingSoon }

class ActionData {
  const ActionData(
      this.title, this.icon, this.cost, this.description, this.image);
  final String title, description, image;
  final IconData icon;
  final int cost;
}

const kStrategyActions = [
  ActionData(
      '発掘', Icons.hardware, 1, '山札の1番上のカードを手札に加える', 'assets/img/act_dig.png'),
  ActionData('鑑定', Icons.search, 1, '他プレイヤーの宝石カード1枚を見る',
      'assets/img/act_appraise.png'),
  ActionData('調査', Icons.visibility, 1, '任意の山札のすべてのカードを見る',
      'assets/img/act_investigate.png'),
  ActionData(
      '整地', Icons.grass, 1, '任意の山札2つを1〜5枚ずつに作り変える', 'assets/img/act_level.png'),
  ActionData(
      '埋葬', Icons.south, 1, '手札のカード1枚を山札の1番上に置く', 'assets/img/act_bury.png'),
  ActionData(
      '強奪', Icons.pan_tool, 2, '他プレイヤーの宝石を自分の手札にする', 'assets/img/act_rob.png'),
  ActionData('独占', Icons.workspace_premium, 1, '任意の山札を効果の対象外にする',
      'assets/img/act_monopoly.png'),
  ActionData('捏造', Icons.swap_horiz, 2, '手札と山札のカードを交換する',
      'assets/img/act_fabricate.png'),
  ActionData(
      '保護', Icons.shield, 1, '手札を任意の枚数、効果対象外にする', 'assets/img/act_protect.png'),
  ActionData('取引', Icons.handshake, 2, '他プレイヤーとカードを1枚ずつ交換',
      'assets/img/act_trade.png'),
];

class ActionCard extends ConsumerWidget {
  const ActionCard({required this.index, required this.data, super.key});
  final int index;
  final ActionData data;

  /// 現状は「発掘」のみ実装済み。それ以外は準備中。
  bool get _implemented => data.title == '発掘';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final selectedAction = ref.watch(selectedActionProvider);
    final notMyTurn = state.isOver || state.currentPlayer != 0;
    final lacksWorkers = !notMyTurn && state.players[0].workers < data.cost;

    final actionState = !_implemented
        ? ActionState.comingSoon
        : (notMyTurn || lacksWorkers)
            ? ActionState.insufficientWorkers
            : (selectedAction == index
                ? ActionState.selected
                : ActionState.usable);

    final tappable = actionState == ActionState.usable ||
        actionState == ActionState.selected;

    final caption = switch (actionState) {
      ActionState.comingSoon => '準備中',
      ActionState.used => '使用済み',
      ActionState.insufficientWorkers => notMyTurn ? '手番ではありません' : 'ワーカー不足',
      ActionState.usable || ActionState.selected => '何度でも使用可',
    };
    final captionColor = switch (actionState) {
      ActionState.comingSoon => kGold,
      ActionState.used || ActionState.insufficientWorkers => Colors.white54,
      ActionState.usable || ActionState.selected => kSelected,
    };

    return Semantics(
      button: true,
      enabled: tappable,
      selected: actionState == ActionState.selected,
      child: InkWell(
        onTap: tappable
            ? () {
                final current = ref.read(selectedActionProvider);
                if (current == index) {
                  ref.read(selectedActionProvider.notifier).state = null;
                  return;
                }
                ref.read(selectedActionProvider.notifier).state = index;
                final deckIndex = ref.read(selectedDeckProvider);
                if (deckIndex != null) maybeConfirmDig(context, ref, deckIndex);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: actionState == ActionState.comingSoon
                ? const Color(0xff0b141a)
                : const Color(0xff16303b),
            border: Border.all(
              color: actionState == ActionState.selected
                  ? kSelected
                  : (actionState == ActionState.comingSoon
                      ? Colors.white24
                      : kGold),
              width: actionState == ActionState.selected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: actionState == ActionState.selected
                ? const [BoxShadow(color: kSelected, blurRadius: 10)]
                : null,
          ),
          child: Opacity(
            opacity: switch (actionState) {
              ActionState.comingSoon => 0.5,
              ActionState.used || ActionState.insufficientWorkers => 0.6,
              ActionState.usable || ActionState.selected => 1,
            },
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
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: kBackground,
                      child: Text(
                        '${data.cost}',
                        style: const TextStyle(
                            color: kGold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Image.asset(data.image, fit: BoxFit.contain),
                  ),
                ),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
                const SizedBox(height: 1),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: captionColor,
                    fontWeight: FontWeight.bold,
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

/// 4. プレイヤー表示エリア（戦略カードエリアの直下）。
/// アバター・名前・自分／手番・手札枚数・ワーカー数をここにまとめ、
/// 他の場所には重複表示しない。タップすると、下の自分の手札エリアの
/// 表示対象がそのプレイヤーに切り替わる。
class PlayerArea extends ConsumerWidget {
  const PlayerArea({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(gameProvider.select((s) => s.players));
    final current = ref.watch(gameProvider.select((s) => s.currentPlayer));
    final viewing = ref.watch(selectedPlayerProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff050a0d),
        border: Border.all(color: kGold),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          for (var i = 0; i < players.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: PlayerTile(
                  player: players[i],
                  active: current == i,
                  self: isSelf(i),
                  viewing: viewing == i,
                  onTap: () =>
                      ref.read(selectedPlayerProvider.notifier).state = i,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlayerTile extends StatelessWidget {
  const PlayerTile({
    required this.player,
    required this.active,
    required this.self,
    required this.viewing,
    required this.onTap,
    super.key,
  });
  final PlayerState player;
  final bool active;
  final bool self;

  /// 手札表示エリアの表示対象になっているか。
  final bool viewing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: player.workers == 0 ? 0.55 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xff1c2530) : Colors.transparent,
              border: Border.all(
                color: active || viewing
                    ? kSelected
                    : (self ? kGold : Colors.white12),
                width: active || viewing || self ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: active || viewing
                  ? const [BoxShadow(color: kSelected, blurRadius: 8)]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (self)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: kGold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            active ? 'あなた（手番）' : (viewing ? 'あなた（表示中）' : 'あなた'),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      playerAvatar(player, 18),
                      if (active && !self)
                        Positioned(
                          top: -8,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: kSelfTurn,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '手番',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (viewing && !self)
                        Positioned(
                          bottom: -6,
                          left: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: kSelected,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '表示中',
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
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.diamond, size: 10, color: player.target.color),
                      const SizedBox(width: 3),
                      Text(
                        '手札 ${player.hand.length}',
                        style: const TextStyle(color: kBeige, fontSize: 10),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hardware, size: 11, color: kGold),
                      const SizedBox(width: 2),
                      Text(
                        '${player.workers}/${PlayerState.kWorkersPerPlayer}',
                        style: const TextStyle(color: kGold, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 5. 自分の手札エリア（プレイヤー表示エリアの下）。
/// プレイヤー表示エリアで選んだプレイヤーの手札を表示する。自分は常に
/// おもてで見える。他プレイヤーは、まだ「鑑定」していないカードは裏面のみ
/// （中身は非公開）で、鑑定済みのカードだけおもてで見える。
class HandArea extends ConsumerWidget {
  const HandArea({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(gameProvider.select((s) => s.players));
    final viewedIndex = ref.watch(selectedPlayerProvider);
    final viewed = players[viewedIndex];
    final self = isSelf(viewedIndex);
    return GoldPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  self
                      ? '${viewed.name}の手札（あなた・タップで詳細）'
                      : '${viewed.name}の手札（非公開・未鑑定は裏面）',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: kBeige, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (self)
                Text(
                  '現在 ${viewed.score}点',
                  style: const TextStyle(
                      color: kGold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
            ],
          ),
          Text(
            '手札上限 $kHandLimit枚（到達でゲーム終了）',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: viewed.hand.isEmpty
                ? const Center(
                    child: Text('まだ宝石がありません。',
                        style: TextStyle(color: kBeige, fontSize: 12)),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: viewed.hand.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => self || viewed.hand[i].revealedToSelf
                        ? HandTile(
                            ownerIndex: viewedIndex,
                            index: i,
                            card: viewed.hand[i],
                          )
                        : const HandBackTile(),
                  ),
          ),
        ],
      ),
    );
  }
}

class HandTile extends ConsumerWidget {
  const HandTile({
    required this.ownerIndex,
    required this.index,
    required this.card,
    super.key,
  });
  final int ownerIndex;
  final int index;
  final HandCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        isSelf(ownerIndex) && ref.watch(selectedHandCardProvider) == index;
    return InkWell(
      onTap: () => showHandCardDetail(context, ref, ownerIndex, index, card),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 62,
        height: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kBeige,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? kSelected : const Color(0xff695b42),
            width: selected ? 3 : 2,
          ),
          boxShadow: selected
              ? const [BoxShadow(color: kSelected, blurRadius: 8)]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (card.protected)
                  const Icon(Icons.shield, size: 12, color: kSelfTurn),
                const Spacer(),
                if (card.doubled)
                  const Text(
                    '×2',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
              ],
            ),
            Expanded(child: Center(child: GemIcon(gem: card.gem, size: 28))),
            Text(
              card.gem.label,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// 他プレイヤーの、まだ「鑑定」していない手札1枚を裏面のみで表す
/// （中身は非公開情報のため見せない）。
class HandBackTile extends StatelessWidget {
  const HandBackTile({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 62,
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xff10151d),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: kGold, width: 2),
        ),
        child: const Center(
          child: Icon(Icons.diamond, color: kGold, size: 26),
        ),
      );
}

/// 手札カードをタップしたときの詳細（宝石色・基本得点・ターゲット一致時の
/// 得点・保護状態・選択ボタン）。他プレイヤーの鑑定済みカードを見る場合は、
/// そのプレイヤー自身のターゲットで判定し、「選択」ボタンは出さない
/// （選択は自分の手札を対象にする今後の戦略のためのもの）。
void showHandCardDetail(
  BuildContext context,
  WidgetRef ref,
  int ownerIndex,
  int index,
  HandCard card,
) {
  final owner = ref.read(gameProvider).players[ownerIndex];
  final self = isSelf(ownerIndex);
  final base = switch (card.gem) {
    Gem.black => -2,
    Gem.white => 1,
    _ => 0,
  };
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kPanel,
      title: Row(
        children: [
          GemIcon(gem: card.gem, size: 22),
          const SizedBox(width: 8),
          Text('${card.gem.label}の宝石'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!self)
            Text('${owner.name}の手札（鑑定済み）',
                style: const TextStyle(
                    color: kBeige, fontWeight: FontWeight.bold)),
          Text('基本得点：$base点', style: const TextStyle(color: kBeige)),
          Text(
            'ターゲット一致時：+3点${card.gem == owner.target ? "（一致中）" : ""}',
            style: const TextStyle(color: kBeige),
          ),
          Text(
            '保護状態：${card.protected ? "保護されている" : "保護されていない"}',
            style: const TextStyle(color: kBeige),
          ),
          if (card.doubled)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('このカードは得点2倍（doubled）',
                  style:
                      TextStyle(color: kDanger, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        if (self)
          FilledButton(
            onPressed: () {
              final notifier = ref.read(selectedHandCardProvider.notifier);
              notifier.state = notifier.state == index ? null : index;
              Navigator.pop(ctx);
            },
            child: const Text('選択'),
          ),
      ],
    ),
  );
}

/// 6. 下部固定ナビゲーション：戦略カード・ターゲット・推理メモ・ログ。
/// 戦略カードは常に画面内に表示されているため、このタブは「ここに
/// ある」ことを示す常時強調のみで、タップ動作は持たない。
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (context, ref, _) => Container(
          decoration: const BoxDecoration(
            color: Color(0xff050a0d),
            border: Border(top: BorderSide(color: kGold)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                NavItem(
                  icon: Icons.style,
                  label: '戦略カード',
                  active: true,
                  onTap: () {},
                ),
                NavItem(
                  icon: Icons.diamond,
                  label: 'ターゲット',
                  active: false,
                  onTap: () => showTargetSheet(context, ref),
                ),
                NavItem(
                  icon: Icons.edit_note,
                  label: '推理メモ',
                  active: false,
                  onTap: () => showMemoSheet(context, ref),
                ),
                NavItem(
                  icon: Icons.forum,
                  label: 'ログ',
                  active: false,
                  onTap: () => showLogSheet(context, ref),
                ),
              ],
            ),
          ),
        ),
      );
}

class NavItem extends StatelessWidget {
  const NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? const Color(0xff123a3d) : Colors.black,
              border: Border.all(
                  color: active ? kSelected : kGold, width: active ? 2 : 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: active ? kSelected : kGold, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? kSelected : kBeige,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// ハンバーガーメニュー。
void showMenuSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kPanel,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh, color: kBeige),
            title: const Text('最初からやり直す'),
            onTap: () {
              ref.read(gameProvider.notifier).reset();
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: kBeige),
            title: const Text('FakeDiggerについて'),
            subtitle: const Text('宝石発掘・推理ゲーム（プロトタイプ）'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}

/// ターゲット（宝石）と得点ルールを表示するモーダル。
void showTargetSheet(BuildContext context, WidgetRef ref) {
  final target = ref.read(gameProvider).players[0].target;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kPanel,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('あなたのターゲット',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            height: 120,
            width: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xff101b23),
              border: Border.all(color: kGold, width: 4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GemIcon(gem: target, size: 64),
          ),
          const SizedBox(height: 12),
          Text('${target.label} +3点 / 白 +1点 / 黒 -2点'),
          const Text('黒以外の5色を集めると +10点', style: TextStyle(color: kBeige)),
          const Text('同じ色を5枚集めると +20点', style: TextStyle(color: kBeige)),
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
    backgroundColor: kPanel,
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

/// ログ（これまでの出来事）を表示するモーダル。
void showLogSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kPanel,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final log = ref.watch(gameProvider.select((s) => s.log));
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ログ',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Expanded(
                  child: log.isEmpty
                      ? const Center(
                          child: Text('まだログがありません。',
                              style: TextStyle(color: kBeige)),
                        )
                      : ListView.builder(
                          reverse: true,
                          itemCount: log.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              log[log.length - 1 - i],
                              style:
                                  const TextStyle(color: kBeige, fontSize: 13),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
