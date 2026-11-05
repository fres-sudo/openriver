import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

class ResultsGraph extends StatelessWidget {
  const ResultsGraph({
    super.key,
    required this.points,
    required this.useBigBlinds,
    required this.semanticsLabel,
  });

  final List<ResultPoint> points;
  final bool useBigBlinds;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: const Size.fromHeight(240),
          painter: _ResultsPainter(
            points: points,
            useBigBlinds: useBigBlinds,
            lineColor: theme.colors.primary,
            gridColor: theme.colors.border,
          ),
        ),
      ),
    );
  }
}

class _ResultsPainter extends CustomPainter {
  const _ResultsPainter({
    required this.points,
    required this.useBigBlinds,
    required this.lineColor,
    required this.gridColor,
  });

  final List<ResultPoint> points;
  final bool useBigBlinds;
  final Color lineColor;
  final Color gridColor;

  double _value(ResultPoint point) =>
      useBigBlinds ? point.cumulativeBigBlinds : point.cumulativeNet.toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;
    final values = points.map(_value).toList();
    var minimum = math.min(0, values.reduce(math.min));
    var maximum = math.max(0, values.reduce(math.max));
    if (minimum == maximum) {
      minimum -= 1;
      maximum += 1;
    }
    final span = maximum - minimum;
    minimum -= span * 0.08;
    maximum += span * 0.08;
    final range = maximum - minimum;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (minimum < 0 && maximum > 0) {
      final zeroY = size.height * (maximum / range);
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), grid);
    }
    Offset offset(int index) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final y = size.height * ((maximum - values[index]) / range);
      return Offset(x, y.clamp(0.0, size.height));
    }

    final path = Path()..moveTo(offset(0).dx, offset(0).dy);
    for (var index = 1; index < points.length; index++) {
      path.lineTo(offset(index).dx, offset(index).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(offset(points.length - 1), 4, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(_ResultsPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.useBigBlinds != useBigBlinds ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}
