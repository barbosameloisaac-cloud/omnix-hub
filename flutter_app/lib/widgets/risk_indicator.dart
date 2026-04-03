import 'dart:math' as math;
import 'package:flutter/material.dart';

class RiskIndicator extends StatelessWidget {
  final double score;
  final String label;
  final double size;
  final bool showLabel;

  const RiskIndicator({
    super.key,
    required this.score,
    required this.label,
    this.size = 80,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0.0, 10.0);
    final fraction = clampedScore / 10.0;
    final color = _scoreColor(clampedScore);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              fraction: fraction,
              color: color,
              bgColor: Colors.grey.shade800,
              strokeWidth: size * 0.1,
            ),
            child: Center(
              child: Text(
                clampedScore.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        if (showLabel && label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 8.0) return Colors.red;
    if (score >= 5.0) return Colors.deepOrange;
    if (score >= 3.0) return Colors.orange;
    if (score >= 1.0) return Colors.amber;
    return Colors.green;
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  _RingPainter({
    required this.fraction,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc
    if (fraction > 0) {
      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
