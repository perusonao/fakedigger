import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() => runApp(const ProviderScope(child: FakeDiggerApp()));

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, __) => const GameScreen())],
    ));

class Player {
  const Player(this.name, this.color, this.cards, this.avatar);
  final String name;
  final Color color;
  final int cards;
  final String avatar;
}

class MineDeck {
  const MineDeck(this.id, this.gems, {this.crown});
  final int id;
  final List<Color> gems;
  final Color? crown;
}

final selectedDeckProvider = StateProvider<int?>((ref) => null);
final selectedActionProvider = StateProvider<int?>((ref) => null);
final memoProvider = StateProvider<String>((ref) => '① 赤 ×　青 ?　黒 ○\n② 赤 ○　青 ?　白 ?\n③ 黄 ?　黒 ○\n④ 青 ?　白 ○');

const ink = Color(0xff071117);
const panel = Color(0xff0d1a22);
const gold = Color(0xffc69a45);
const parchment = Color(0xffe5d5ad);

class FakeDiggerApp extends ConsumerWidget {
  const FakeDiggerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'FakeDigger',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
          fontFamily: 'serif',
          useMaterial3: true,
        ),
        routerConfig: ref.watch(routerProvider),
      );
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});
  static const players = [
    Player('ゼファ', Color(0xff46aee8), 4, '⚔'),
    Player('ノクス', Color(0xff76688e), 3, '☾'),
    Player('ミア', Color(0xffe5ad54), 5, '✦'),
  ];
  static const decks = [
    MineDeck(1, [Colors.black, Colors.white]),
    MineDeck(2, [Colors.red, Colors.blue, Colors.white, Colors.white]),
    MineDeck(3, [Colors.amber, Colors.brown], crown: Colors.blue),
    MineDeck(4, [Colors.blue, Colors.white]),
    MineDeck(5, [Colors.green, Colors.amber]),
    MineDeck(6, [Colors.red, Colors.white]),
    MineDeck(7, [Colors.blue, Colors.black, Colors.white]),
    MineDeck(8, [Colors.amber, Colors.black, Colors.white], crown: Colors.red),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 900;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(child: Header(players: players)),
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverToBoxAdapter(
                  child: compact
                      ? const Column(children: [RoundPanel(), SizedBox(height: 12), MineBoard(decks: decks), SizedBox(height: 12), TargetPanel()])
                      : const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 165, child: RoundPanel()),
                          SizedBox(width: 12),
                          Expanded(child: MineBoard(decks: decks)),
                          SizedBox(width: 12),
                          SizedBox(width: 180, child: TargetPanel()),
                        ]),
                ),
              ),
              const SliverToBoxAdapter(child: StrategySection()),
              const SliverToBoxAdapter(child: HelpSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ]);
          }),
        ),
      );
}

class Header extends StatelessWidget {
  const Header({required this.players, super.key});
  final List<Player> players;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(color: Color(0xff050a0d), border: Border(bottom: BorderSide(color: gold))),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 8, children: [
          const SizedBox(width: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FakeDigger', style: TextStyle(color: Color(0xffffd277), fontSize: 28, fontWeight: FontWeight.bold)),
            Text('フェイクディガー', style: TextStyle(color: parchment, fontSize: 11)),
          ])),
          ...players.map((p) => PlayerChip(player: p)),
          const IconButton(tooltip: 'ログ', onPressed: null, icon: Icon(Icons.receipt_long, color: gold)),
          const IconButton(tooltip: '設定', onPressed: null, icon: Icon(Icons.settings, color: gold)),
        ]),
      );
}

class PlayerChip extends StatelessWidget {
  const PlayerChip({required this.player, super.key});
  final Player player;
  @override
  Widget build(BuildContext context) => Container(
        width: 185,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: panel, border: Border.all(color: gold), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          CircleAvatar(backgroundColor: player.color, child: Text(player.avatar)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)), Text('手札 ${player.cards}枚', style: const TextStyle(color: parchment))])),
          const Icon(Icons.style, color: Color(0xff7187a3)),
        ]),
      );
}

class GoldPanel extends StatelessWidget {
  const GoldPanel({required this.child, this.padding = const EdgeInsets.all(12), super.key});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: panel, border: Border.all(color: gold), borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)]),
        child: child,
      );
}

class RoundPanel extends StatelessWidget {
  const RoundPanel({super.key});
  @override
  Widget build(BuildContext context) => GoldPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ラウンド  3 / ∞', style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(color: gold),
        const Text('あなたの番です', textAlign: TextAlign.center, style: TextStyle(color: Color(0xff72e1c1), fontWeight: FontWeight.bold)),
        const SizedBox(height: 25),
        const Text('スタートプレイヤー'),
        const SizedBox(height: 8),
        const Row(children: [CircleAvatar(backgroundColor: Color(0xffd86c77), child: Text('♛')), SizedBox(width: 8), Text('アルル')]),
        const Divider(height: 35),
        const Text('ワーカー'),
        const SizedBox(height: 8),
        const Text('⛏   ⛏', style: TextStyle(fontSize: 28, color: gold)),
        const Divider(height: 35),
        const Text('独占チップ'),
        const Text('♛', style: TextStyle(fontSize: 28, color: Colors.amber)),
        const SizedBox(height: 22),
        OutlinedButton(onPressed: () {}, child: const Text('?  DAI早見表')),
      ]));
}

class MineBoard extends StatelessWidget {
  const MineBoard({required this.decks, super.key});
  final List<MineDeck> decks;
  @override
  Widget build(BuildContext context) => GoldPanel(child: Column(children: [
        const Text('—  山札エリア（DAIが見える） —', style: TextStyle(color: parchment, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 155, childAspectRatio: .72, crossAxisSpacing: 16, mainAxisSpacing: 18),
          itemCount: decks.length,
          itemBuilder: (_, i) => DeckCard(deck: decks[i]),
        ),
      ]));
}

class DeckCard extends ConsumerWidget {
  const DeckCard({required this.deck, super.key});
  final MineDeck deck;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDeckProvider) == deck.id;
    return Semantics(button: true, selected: selected, label: '山札${deck.id}、5枚', child: InkWell(
      onTap: () => ref.read(selectedDeckProvider.notifier).state = deck.id,
      borderRadius: BorderRadius.circular(8),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(left: 6, right: -6, top: 10, bottom: -8, child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xff766b59), borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.black)))),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: parchment, borderRadius: BorderRadius.circular(7), border: Border.all(color: selected ? Colors.cyanAccent : const Color(0xff695b42), width: selected ? 3 : 2), boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 6)]),
          child: Column(children: [
            CircleAvatar(radius: 16, backgroundColor: const Color(0xff6a5e49), child: Text('${deck.id}', style: const TextStyle(color: Colors.white, fontSize: 20))),
            const Divider(color: Color(0xff8a7754)),
            Expanded(child: Center(child: Wrap(spacing: 3, children: deck.gems.map((c) => Container(width: 19, height: 19, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black)))).toList()))),
            const Text('5枚', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
        ),
        if (deck.crown != null) Positioned(right: -7, top: -16, child: Text('♛', style: TextStyle(fontSize: 36, color: deck.crown))),
      ]),
    ));
  }
}

class TargetPanel extends ConsumerWidget {
  const TargetPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        GoldPanel(child: Column(children: [
          const Text('あなたのターゲット', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(height: 150, width: 120, decoration: BoxDecoration(color: const Color(0xff101b23), border: Border.all(color: gold, width: 4), borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.diamond, size: 76, color: Color(0xff42b9f1)))),
          const SizedBox(height: 10),
          const Text('白 +1点 / 黒 -2点'),
          const Text('5色集めると +10点', style: TextStyle(color: parchment)),
        ])),
        const SizedBox(height: 12),
        GoldPanel(child: Column(children: [
          const Text('推理メモ（あなただけ）', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(ref.watch(memoProvider), style: const TextStyle(height: 1.7)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _editMemo(context, ref), child: const Text('メモを編集')),
        ])),
      ]);

  void _editMemo(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(memoProvider));
    showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('推理メモ'), content: TextField(controller: controller, maxLines: 6, autofocus: true), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
      FilledButton(onPressed: () { ref.read(memoProvider.notifier).state = controller.text; Navigator.pop(context); }, child: const Text('保存')),
    ]));
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
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: [
        const Padding(padding: EdgeInsets.all(10), child: Text('—  戦略カード（ワーカーを置いて効果を使用） —', style: TextStyle(color: parchment, fontWeight: FontWeight.bold))),
        LayoutBuilder(builder: (context, box) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: box.maxWidth > 900 ? 5 : box.maxWidth > 520 ? 3 : 2, childAspectRatio: .82, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: actions.length,
          itemBuilder: (_, i) => ActionCard(index: i, data: actions[i]),
        )),
      ]));
}

class ActionCard extends ConsumerWidget {
  const ActionCard({required this.index, required this.data, super.key});
  final int index;
  final ActionData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedActionProvider) == index;
    return Semantics(button: true, selected: selected, child: InkWell(
      onTap: () => ref.read(selectedActionProvider.notifier).state = index,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: panel, border: Border.all(color: selected ? Colors.cyanAccent : gold, width: selected ? 3 : 1), borderRadius: BorderRadius.circular(6)), child: Column(children: [
        Row(children: [Expanded(child: Text(data.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), CircleAvatar(radius: 17, backgroundColor: ink, child: Text('${data.cost}', style: const TextStyle(color: gold)))]),
        Expanded(child: Center(child: Text(data.icon, style: const TextStyle(fontSize: 48)))),
        Text(data.description, textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
      ])),
    ));
  }
}

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, box) => GridView.count(
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
            HelpCard(title: '手札エリア', steps: ['🔴 3', '⚪ 1', '⚫ 12', '🔵 3', '?']),
            HelpCard(title: 'ゲーム終了（得点結果）', steps: ['🥇 アルル 42点', '🥈 ゼファ 28点', '🥉 ノクス 21点']),
          ],
        )),
      );
}

class HelpCard extends StatelessWidget {
  const HelpCard({required this.title, required this.steps, super.key});
  final String title;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => GoldPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(color: gold),
        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (var i = 0; i < steps.length; i++) ...[Flexible(child: Text(steps[i], textAlign: TextAlign.center, style: const TextStyle(color: parchment))), if (i < steps.length - 1) const Icon(Icons.arrow_forward, color: gold)]])),
      ]));
}
