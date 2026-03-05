import 'package:flutter/material.dart';

/// Custom painter for a minimal area/line chart used in the dashboard
/// temperature trend card.
///
/// Takes a list of data points and renders a smooth line with gradient fill.
class TrendChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final Color fillColor;

  TrendChartPainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minVal = data.reduce((a, b) => a < b ? a : b) - 2;
    final maxVal = data.reduce((a, b) => a > b ? a : b) + 2;
    final range = maxVal - minVal;

    double xFor(int i) => (i / (data.length - 1)) * size.width;
    double yFor(double v) => size.height - ((v - minVal) / range) * size.height;

    // Build path
    final path = Path()..moveTo(xFor(0), yFor(data[0]));
    for (int i = 1; i < data.length; i++) {
      // Simple cubic bezier for smooth curves
      final prevX = xFor(i - 1);
      final currX = xFor(i);
      final midX = (prevX + currX) / 2;
      path.cubicTo(midX, yFor(data[i - 1]), midX, yFor(data[i]), currX, yFor(data[i]));
    }

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor.withAlpha(60), fillColor.withAlpha(5)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw dots at each data point
    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(Offset(xFor(i), yFor(data[i])), 3, dotPaint);
    }
    // White inner dot for last point
    final lastDot = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(xFor(data.length - 1), yFor(data.last)),
      1.5,
      lastDot,
    );
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter old) =>
      old.data != data || old.lineColor != lineColor;
}
