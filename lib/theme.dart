import 'package:flutter/material.dart';

/// FakeDigger共通カラーパレット・テーマ。
const kBackground = Color(0xff07131a);
const kPanel = Color(0xff0d1b24);
const kGold = Color(0xffb78a3e);
const kBeige = Color(0xffe8d5a4);
const kSelected = Color(0xff20e0ea);
const kSelfTurn = Color(0xff087a5a);
const kDanger = Color(0xffd14b4b);

ThemeData buildAppTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kGold,
        brightness: Brightness.dark,
      ),
      fontFamily: 'AppJP',
      useMaterial3: true,
    );

/// 金枠のパネル（山札エリア・戦略エリアなど、盤面の主要ブロック共通の器）。
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
          color: kPanel,
          border: Border.all(color: kGold),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        child: child,
      );
}
