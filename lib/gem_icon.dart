import 'package:flutter/material.dart';

import 'game/models.dart';

/// 宝石を単なる色付き丸ではなく、多角形の宝石らしい形で描く。
/// 正式な宝石画像が用意できるまでの仮実装（CustomPaint）。
class GemIcon extends StatelessWidget {
  const GemIcon(
      {required this.gem, this.size = 24, this.dim = false, super.key});
  final Gem gem;
  final double size;

  /// 空の山札など、薄く沈めて表示したい場合。
  final bool dim;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _GemPainter(gem.color, dim: dim),
      );
}

class _GemPainter extends CustomPainter {
  _GemPainter(this.color, {required this.dim});
  final Color color;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.36)
      ..lineTo(w * 0.76, h)
      ..lineTo(w * 0.24, h)
      ..lineTo(0, h * 0.36)
      ..close();

    final fill = Paint()..color = dim ? color.withValues(alpha: 0.25) : color;
    canvas.drawPath(path, fill);

    final facet = Paint()
      ..color = Colors.white.withValues(alpha: dim ? 0.15 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), facet);
    canvas.drawLine(Offset(0, h * 0.36), Offset(w, h * 0.36), facet);

    final border = Paint()
      ..color = (color == Colors.black ? Colors.white : Colors.black)
          .withValues(alpha: dim ? 0.2 : 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _GemPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dim != dim;
}
