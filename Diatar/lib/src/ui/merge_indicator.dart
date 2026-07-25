import 'package:flutter/material.dart';

enum MergeIndicatorVisual { hidden, circle, upperBrace, lowerBrace }

class MergeIndicator extends StatelessWidget {
  const MergeIndicator({
    super.key,
    required this.visual,
    this.onTap,
    this.color,
    this.activeColor,
  });

  final MergeIndicatorVisual visual;
  final VoidCallback? onTap;
  final Color? color;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    if (visual == MergeIndicatorVisual.hidden) {
      return const SizedBox(width: 18, height: 30);
    }

    final ThemeData theme = Theme.of(context);
    final bool active =
        visual == MergeIndicatorVisual.upperBrace ||
        visual == MergeIndicatorVisual.lowerBrace;
    final Color stroke = active
        ? (activeColor ?? theme.colorScheme.outline)
        : (color ?? theme.colorScheme.outlineVariant);
    final Widget child = SizedBox(
      width: 18,
      height: 30,
      child: CustomPaint(
        painter: _MergeIndicatorPainter(visual: visual, color: stroke),
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkResponse(radius: 18, onTap: onTap, child: child);
  }
}

class _MergeIndicatorPainter extends CustomPainter {
  const _MergeIndicatorPainter({required this.visual, required this.color});

  final MergeIndicatorVisual visual;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final double midY = size.height / 2;
    const double startX = 3;
    final double lineX = size.width * 0.36;
    final double endX = size.width - 2;

    switch (visual) {
      case MergeIndicatorVisual.hidden:
        return;
      case MergeIndicatorVisual.circle:
        final Paint fill = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(lineX + 1, midY), 2.7, fill);
      case MergeIndicatorVisual.upperBrace:
        canvas.drawLine(Offset(lineX, midY), Offset(endX, midY), paint);
        canvas.drawLine(
          Offset(lineX, midY + 0.5),
          Offset(lineX, size.height - 2),
          paint,
        );
        canvas.drawLine(
          Offset(lineX, size.height - 2),
          const Offset(startX, 0).translate(0, size.height - 2),
          paint,
        );
      case MergeIndicatorVisual.lowerBrace:
        canvas.drawLine(const Offset(startX, 2), Offset(lineX, 2), paint);
        canvas.drawLine(Offset(lineX, 2), Offset(lineX, midY - 0.5), paint);
        canvas.drawLine(Offset(lineX, midY), Offset(endX, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MergeIndicatorPainter oldDelegate) {
    return oldDelegate.visual != visual || oldDelegate.color != color;
  }
}