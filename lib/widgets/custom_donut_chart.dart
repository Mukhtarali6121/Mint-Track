import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../common/currency_formatter.dart';
import '../theme/app_colors.dart';

class CustomDonutChart extends StatefulWidget {
  final List<CustomDonutSegment> segments;
  final double animationProgress;
  final int? selectedIndex;
  final ValueChanged<int?> onSegmentSelected;
  final String currencySymbol;
  final double totalAmount;

  const CustomDonutChart({
    super.key,
    required this.segments,
    required this.animationProgress,
    required this.selectedIndex,
    required this.onSegmentSelected,
    required this.currencySymbol,
    required this.totalAmount,
  });

  @override
  State<CustomDonutChart> createState() => _CustomDonutChartState();
}

class _CustomDonutChartState extends State<CustomDonutChart> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = math.min(width * 0.85, 300.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPos = details.localPosition;
            final center = Offset(box.size.width / 2, box.size.height / 2);
            final radius = math.min(box.size.width, box.size.height) * 0.38;
            final innerRadius = radius * 0.52;

            final dx = localPos.dx - center.dx;
            final dy = localPos.dy - center.dy;
            final dist = math.sqrt(dx * dx + dy * dy);

            if (dist >= innerRadius - 15 && dist <= radius + 25) {
              double touchAngle = math.atan2(dy, dx);
              double normalized = touchAngle - (-math.pi / 2);
              while (normalized < 0) {
                normalized += 2 * math.pi;
              }
              while (normalized >= 2 * math.pi) {
                normalized -= 2 * math.pi;
              }

              double currentAngle = 0.0;
              int? tappedIndex;
              for (int i = 0; i < widget.segments.length; i++) {
                final sweep = widget.segments[i].sweepAngle;
                if (normalized >= currentAngle &&
                    normalized <= currentAngle + sweep) {
                  tappedIndex = i;
                  break;
                }
                currentAngle += sweep;
              }

              if (tappedIndex != null) {
                if (widget.selectedIndex == tappedIndex) {
                  widget.onSegmentSelected(null);
                } else {
                  widget.onSegmentSelected(tappedIndex);
                }
              } else {
                widget.onSegmentSelected(null);
              }
            } else {
              if (widget.selectedIndex != null) {
                widget.onSegmentSelected(null);
              }
            }
          },
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              size: Size(width, height),
              painter: _DonutChartPainter(
                segments: widget.segments,
                animationProgress: widget.animationProgress,
                selectedIndex: widget.selectedIndex,
                currencySymbol: widget.currencySymbol,
                totalAmount: widget.totalAmount,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomDonutSegment {
  final String label;
  final double value;
  final double percentage;
  final Color color;
  final double sweepAngle;

  CustomDonutSegment({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
    required this.sweepAngle,
  });
}

class _SegmentLayout {
  final int index;
  final CustomDonutSegment segment;
  final double startAngle;
  final double sweepAngle;

  _SegmentLayout({
    required this.index,
    required this.segment,
    required this.startAngle,
    required this.sweepAngle,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<CustomDonutSegment> segments;
  final double animationProgress;
  final int? selectedIndex;
  final String currencySymbol;
  final double totalAmount;

  _DonutChartPainter({
    required this.segments,
    required this.animationProgress,
    required this.selectedIndex,
    required this.currencySymbol,
    required this.totalAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.38;
    final strokeWidth = maxRadius * 0.44;
    final baseRadius = maxRadius - (strokeWidth / 2);

    final bgGlowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, baseRadius, bgGlowPaint);

    final bgRingPaint = Paint()
      ..color = const Color(0xFFF1F5F9).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8;
    canvas.drawCircle(center, baseRadius, bgRingPaint);

    final double gap = segments.length > 1 ? 0.08 : 0.0;
    final totalGap = gap * segments.length;
    final effectiveTotalSweep = math.max(0.0, (2 * math.pi - totalGap));

    double startAngle = -math.pi / 2;
    final List<_SegmentLayout> layouts = [];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final proportion = seg.sweepAngle / (2 * math.pi);
      final segSweep = (proportion * effectiveTotalSweep) * animationProgress;

      layouts.add(
        _SegmentLayout(
          index: i,
          segment: seg,
          startAngle: startAngle + (gap / 2),
          sweepAngle: math.max(0.001, segSweep),
        ),
      );

      startAngle += (proportion * effectiveTotalSweep) + gap;
    }

    for (final layout in layouts) {
      final isSelected = selectedIndex == layout.index;
      final isAnySelected = selectedIndex != null;

      Color segColor = layout.segment.color;
      if (isAnySelected && !isSelected) {
        segColor = segColor.withValues(alpha: 0.35);
      }

      final paint = Paint()
        ..color = segColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 6 : strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(
        center: center,
        radius: isSelected ? baseRadius + 3 : baseRadius,
      );

      canvas.drawArc(rect, layout.startAngle, layout.sweepAngle, false, paint);
    }

    _drawCenterContent(canvas, center, baseRadius - strokeWidth / 2);
  }

  void _drawCenterContent(Canvas canvas, Offset center, double innerRadius) {
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < segments.length) {
      final seg = segments[selectedIndex!];

      final percentPainter = TextPainter(
        text: TextSpan(
          text: '${seg.percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: seg.color,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final categoryPainter = TextPainter(
        text: TextSpan(
          text: seg.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(10, innerRadius * 1.8));

      final amountPainter = TextPainter(
        text: TextSpan(
          text: CurrencyFormatter.format(
            amount: seg.value,
            symbol: currencySymbol,
            decimalDigits: 0,
            spaceBetween: false,
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final totalHeight =
          percentPainter.height +
          categoryPainter.height +
          amountPainter.height +
          6;
      double currentY = center.dy - totalHeight / 2;

      percentPainter.paint(
        canvas,
        Offset(center.dx - percentPainter.width / 2, currentY),
      );
      currentY += percentPainter.height + 2;

      categoryPainter.paint(
        canvas,
        Offset(center.dx - categoryPainter.width / 2, currentY),
      );
      currentY += categoryPainter.height + 2;

      amountPainter.paint(
        canvas,
        Offset(center.dx - amountPainter.width / 2, currentY),
      );
    } else {
      final totalLabelPainter = TextPainter(
        text: TextSpan(
          text: 'Total',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final totalValPainter = TextPainter(
        text: TextSpan(
          text: CurrencyFormatter.format(
            amount: totalAmount,
            symbol: currencySymbol,
            decimalDigits: 0,
            spaceBetween: false,
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final totalHeight = totalLabelPainter.height + totalValPainter.height + 2;
      final startY = center.dy - totalHeight / 2;

      totalLabelPainter.paint(
        canvas,
        Offset(center.dx - totalLabelPainter.width / 2, startY),
      );
      totalValPainter.paint(
        canvas,
        Offset(
          center.dx - totalValPainter.width / 2,
          startY + totalLabelPainter.height + 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.segments != segments ||
        oldDelegate.totalAmount != totalAmount;
  }
}
