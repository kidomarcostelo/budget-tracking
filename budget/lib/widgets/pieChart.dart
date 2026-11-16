import 'dart:math';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/widgets/pinWheelReveal.dart';
import 'package:budget/functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

Color getSpendingHeatmapColor(int index, int totalCount) {
  if (totalCount <= 1) {
    return const Color(0xFFFF6B6B);
  }
  final double ratio = (index / (totalCount - 1)).clamp(0.0, 1.0);
  final double hue = ratio * 165.0;
  const double saturation = 0.78;
  const double value = 0.95;
  return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
}

class CategoryTotal {
  CategoryTotal(
    this.categoryPk,
    this.total,
  );

  String categoryPk;
  double total;
}

class CategoryTotalDetailed {
  CategoryTotalDetailed(this.categoryPk, this.total, this.categoryDetails);

  String categoryPk;
  double total;
  TransactionCategory categoryDetails;
}

Future<List<CategoryTotalDetailed>> getCategoryDetails(
    List<CategoryTotal> data) async {
  List<CategoryTotalDetailed> output = [];
  for (CategoryTotal element in data) {
    output.add(
      CategoryTotalDetailed(
        element.categoryPk,
        element.total,
        await database.getCategoryInstance(element.categoryPk),
      ),
    );
  }
  return output;
}

class EmptyPieChart extends StatelessWidget {
  const EmptyPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class PieChartWrapper extends StatelessWidget {
  const PieChartWrapper({
    Key? key,
    required this.data,
    required this.totalSpent,
    required this.setSelectedCategory,
    required this.pieChartDisplayStateKey,
    this.middleColor,
    this.disableLarge = false,
    this.isDonut = false,
    this.customWidth,
    this.customHeight,
  }) : super(key: key);

  final List<CategoryWithTotal> data;
  final double totalSpent;
  final Function(String categoryPk, TransactionCategory? category)
      setSelectedCategory;
  final GlobalKey<PieChartDisplayState>? pieChartDisplayStateKey;
  final Color? middleColor;
  final bool disableLarge;
  final bool isDonut;
  final double? customWidth;
  final double? customHeight;

  @override
  Widget build(BuildContext context) {
    final List<CategoryWithTotal> dataFiltered = [];
    int numberZeroTransactions = 0;
    // Remove all the categories with a total of 0
    // This fixes the touch index offset for PieChartDisplay!
    for (CategoryWithTotal categoryWithTotal in data) {
      if (categoryWithTotal.total == 0) {
        numberZeroTransactions++;
      } else {
        dataFiltered.add(categoryWithTotal);
      }
    }
    // Sort descending by absolute spending so index 0 is always largest spending category
    dataFiltered.sort((a, b) => b.total.abs().compareTo(a.total.abs()));

    final double containerWidth = customWidth ??
        (enableDoubleColumn(context) == false || disableLarge ? 320.0 : 360.0);
    final double containerHeight = customHeight ??
        (enableDoubleColumn(context) == false || disableLarge ? 220.0 : 250.0);

    return Container(
      width: containerWidth,
      height: containerHeight,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          ScaledAnimatedSwitcher(
            keyToWatch:
                (data.length <= 0 || numberZeroTransactions == data.length)
                    .toString(),
            child: data.length <= 0 || numberZeroTransactions == data.length
                ? Container(
                    key: const ValueKey(1),
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.3),
                    ),
                  )
                : PieChartDisplay(
                    data: dataFiltered,
                    totalSpent: totalSpent,
                    setSelectedCategory: setSelectedCategory,
                    key: pieChartDisplayStateKey,
                    disableLarge: disableLarge,
                  ),
          ),
          if (isDonut) ...[
            IgnorePointer(
              child: Center(
                child: Container(
                  width: enableDoubleColumn(context) == false || disableLarge
                      ? 105
                      : 130,
                  height: enableDoubleColumn(context) == false || disableLarge
                      ? 105
                      : 130,
                  decoration: BoxDecoration(
                    color: middleColor?.withOpacity(0.2) ??
                        getColor(context, "white").withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: enableDoubleColumn(context) == false || disableLarge
                      ? 80
                      : 110,
                  height: enableDoubleColumn(context) == false || disableLarge
                      ? 80
                      : 110,
                  decoration: BoxDecoration(
                      color: middleColor ??
                          Theme.of(context).colorScheme.background,
                      shape: BoxShape.circle),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

GlobalKey<PieChartDisplayState> pieChartDisplayStatePastBudgetKey = GlobalKey();

class PieChartDisplay extends StatefulWidget {
  PieChartDisplay({
    Key? key,
    required this.data,
    required this.totalSpent,
    required this.setSelectedCategory,
    this.disableLarge = false,
  }) : super(key: key);

  final List<CategoryWithTotal> data;
  final double totalSpent;
  final Function(String categoryPk, TransactionCategory? category)
      setSelectedCategory;
  final bool disableLarge;

  @override
  State<StatefulWidget> createState() => PieChartDisplayState();
}

class PieChartDisplayState extends State<PieChartDisplay> {
  int touchedIndex = -1;
  bool scaleIn = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      if (mounted) {
        setState(() {
          scaleIn = true;
        });
      }
    });
  }

  void setTouchedIndex(int index) {
    setState(() {
      touchedIndex = index;
    });
  }

  void setTouchedCategoryPk(String? categoryPk) {
    if (categoryPk == null) {
      setTouchedIndex(-1);
      return;
    }
    int index = 0;
    bool found = false;
    for (CategoryWithTotal category in widget.data) {
      if (category.category.categoryPk == categoryPk) {
        found = true;
        break;
      }
      index++;
    }
    if (found == false)
      setTouchedIndex(-1);
    else
      setTouchedIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final double pieRadius =
        enableDoubleColumn(context) == false || widget.disableLarge
            ? 66.0
            : 88.0;
    final Color textColor = getColor(context, "black");
    final Color subtextColor = getColor(context, "textLight");

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : (enableDoubleColumn(context) == false || widget.disableLarge
                    ? 320.0
                    : 360.0);
        final double height =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : (enableDoubleColumn(context) == false || widget.disableLarge
                    ? 220.0
                    : 250.0);
        final Size chartSize = Size(width, height);

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PinWheelReveal(
                delay: Duration.zero,
                duration: const Duration(milliseconds: 850),
                child: PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            return;
                          }
                          if (event.runtimeType == FlTapDownEvent &&
                              touchedIndex !=
                                  pieTouchResponse
                                      .touchedSection!.touchedSectionIndex) {
                            touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                            widget.setSelectedCategory(
                              widget.data[touchedIndex].category.categoryPk,
                              widget.data[touchedIndex].category,
                            );
                          } else if (event.runtimeType == FlTapDownEvent) {
                            touchedIndex = -1;
                            widget.setSelectedCategory("-1", null);
                          } else if (event.runtimeType ==
                              FlLongPressMoveUpdate) {
                            touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                            widget.setSelectedCategory(
                              widget.data[touchedIndex].category.categoryPk,
                              widget.data[touchedIndex].category,
                            );
                          }
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 0,
                    centerSpaceRadius: 0,
                    sections: showingSections(),
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 1300),
                  swapAnimationCurve: const ElasticOutCurve(0.6),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    size: chartSize,
                    painter: PieChartCalloutPainter(
                      data: widget.data,
                      totalSpent: widget.totalSpent,
                      touchedIndex: touchedIndex,
                      pieRadius: pieRadius,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      startDegreeOffset: -90.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<PieChartSectionData> showingSections() {
    final double baseRadius =
        enableDoubleColumn(context) == false || widget.disableLarge
            ? 66.0
            : 88.0;

    return List.generate(widget.data.length, (i) {
      final bool isTouched = i == touchedIndex;
      final double radius = isTouched ? baseRadius + 6.0 : baseRadius;
      final Color color = getSpendingHeatmapColor(i, widget.data.length);

      return PieChartSectionData(
        color: color,
        value: widget.totalSpent == 0
            ? 5.0
            : (widget.data[i].total / widget.totalSpent).abs(),
        title: "",
        radius: radius,
        badgeWidget: null,
      );
    });
  }
}

class CalloutCandidate {
  CalloutCandidate({
    required this.index,
    required this.categoryName,
    required this.percent,
    required this.color,
    required this.midAngleRad,
    required this.slicePoint,
    required this.isRight,
  });

  final int index;
  final String categoryName;
  final double percent;
  final Color color;
  final double midAngleRad;
  final Offset slicePoint;
  final bool isRight;
  double targetY = 0.0;
}

void resolveCalloutCollisions(
    List<CalloutCandidate> list, double minY, double maxY, double minSpacing) {
  if (list.isEmpty) return;
  if (list.length == 1) {
    list[0].targetY = list[0].slicePoint.dy.clamp(minY, maxY);
    return;
  }
  for (final c in list) {
    c.targetY = c.slicePoint.dy.clamp(minY, maxY);
  }
  for (int i = 1; i < list.length; i++) {
    if (list[i].targetY < list[i - 1].targetY + minSpacing) {
      list[i].targetY = list[i - 1].targetY + minSpacing;
    }
  }
  if (list.last.targetY > maxY) {
    final double overflow = list.last.targetY - maxY;
    for (int i = 0; i < list.length; i++) {
      list[i].targetY -= overflow;
    }
  }
  for (int i = list.length - 2; i >= 0; i--) {
    if (list[i].targetY > list[i + 1].targetY - minSpacing) {
      list[i].targetY = list[i + 1].targetY - minSpacing;
    }
  }
  if (list.first.targetY < minY) {
    final double underflow = minY - list.first.targetY;
    for (int i = 0; i < list.length; i++) {
      list[i].targetY += underflow;
    }
  }
}

class PieChartCalloutPainter extends CustomPainter {
  PieChartCalloutPainter({
    required this.data,
    required this.totalSpent,
    required this.touchedIndex,
    required this.pieRadius,
    required this.textColor,
    required this.subtextColor,
    this.startDegreeOffset = -90.0,
  });

  final List<CategoryWithTotal> data;
  final double totalSpent;
  final int touchedIndex;
  final double pieRadius;
  final Color textColor;
  final Color subtextColor;
  final double startDegreeOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSpent <= 0 || data.isEmpty) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    double currentAngleDeg = startDegreeOffset;
    final List<CalloutCandidate> leftCandidates = [];
    final List<CalloutCandidate> rightCandidates = [];

    for (int i = 0; i < data.length; i++) {
      final double fraction =
          totalSpent == 0 ? 0.0 : (data[i].total / totalSpent).abs();
      final double percent = fraction * 100.0;
      final double sweepDeg = fraction * 360.0;
      final double midAngleDeg = currentAngleDeg + sweepDeg / 2.0;
      currentAngleDeg += sweepDeg;

      // Suppress callouts for slices < 1%
      if (percent < 1.0) continue;

      final double midAngleRad = midAngleDeg * (pi / 180.0);
      final double cosVal = cos(midAngleRad);
      final double sinVal = sin(midAngleRad);

      final Offset slicePoint = Offset(
        center.dx + cosVal * pieRadius,
        center.dy + sinVal * pieRadius,
      );

      final candidate = CalloutCandidate(
        index: i,
        categoryName: data[i].category.name,
        percent: percent,
        color: getSpendingHeatmapColor(i, data.length),
        midAngleRad: midAngleRad,
        slicePoint: slicePoint,
        isRight: cosVal >= 0,
      );

      if (candidate.isRight) {
        rightCandidates.add(candidate);
      } else {
        leftCandidates.add(candidate);
      }
    }

    leftCandidates.sort((a, b) => a.slicePoint.dy.compareTo(b.slicePoint.dy));
    rightCandidates.sort((a, b) => a.slicePoint.dy.compareTo(b.slicePoint.dy));

    const double minY = 18.0;
    final double maxY = size.height - 18.0;
    const double preferredSpacing = 28.0;

    final double leftSpacing = leftCandidates.isEmpty
        ? preferredSpacing
        : min(preferredSpacing, (maxY - minY) / leftCandidates.length);
    final double rightSpacing = rightCandidates.isEmpty
        ? preferredSpacing
        : min(preferredSpacing, (maxY - minY) / rightCandidates.length);

    resolveCalloutCollisions(leftCandidates, minY, maxY, leftSpacing);
    resolveCalloutCollisions(rightCandidates, minY, maxY, rightSpacing);

    final bool hasSelection = touchedIndex >= 0;

    // Render left candidates
    for (final c in leftCandidates) {
      _drawCallout(
        canvas: canvas,
        size: size,
        center: center,
        c: c,
        isLeft: true,
        hasSelection: hasSelection,
      );
    }

    // Render right candidates
    for (final c in rightCandidates) {
      _drawCallout(
        canvas: canvas,
        size: size,
        center: center,
        c: c,
        isLeft: false,
        hasSelection: hasSelection,
      );
    }
  }

  void _drawCallout({
    required Canvas canvas,
    required Size size,
    required Offset center,
    required CalloutCandidate c,
    required bool isLeft,
    required bool hasSelection,
  }) {
    final bool isSelected = touchedIndex == c.index;
    final double opacity = hasSelection && !isSelected ? 0.35 : 1.0;

    final titlePainter = TextPainter(
      text: TextSpan(
        text: c.categoryName,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: textColor.withOpacity(opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: "...",
    );

    final percentPainter = TextPainter(
      text: TextSpan(
        text: "${c.percent.toStringAsFixed(1)} %",
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: subtextColor.withOpacity(opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    final double textAnchor = isLeft
        ? max(8.0, center.dx - pieRadius - 18.0)
        : min(size.width - 8.0, center.dx + pieRadius + 18.0);
    final double maxTextWidth = isLeft
        ? max(20.0, textAnchor - 4.0)
        : max(20.0, size.width - 4.0 - textAnchor);

    titlePainter.layout(maxWidth: maxTextWidth);
    percentPainter.layout(maxWidth: maxTextWidth);

    final double lineEndX = isLeft ? textAnchor + 4.0 : textAnchor - 4.0;
    final double targetY = c.targetY;

    final Path linePath = Path();
    linePath.moveTo(c.slicePoint.dx, c.slicePoint.dy);

    const double tickDist = 8.0;
    final double tickX = c.slicePoint.dx + cos(c.midAngleRad) * tickDist;
    final double tickY = c.slicePoint.dy + sin(c.midAngleRad) * tickDist;
    linePath.lineTo(tickX, tickY);

    final double elbowX = isLeft
        ? min(tickX - 6.0, lineEndX + 10.0)
        : max(tickX + 6.0, lineEndX - 10.0);
    linePath.lineTo(elbowX, targetY);
    linePath.lineTo(lineEndX, targetY);

    final linePaint = Paint()
      ..color = c.color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.2 : 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    final double titleX = isLeft ? textAnchor - titlePainter.width : textAnchor;
    final double percentX =
        isLeft ? textAnchor - percentPainter.width : textAnchor;
    final double titleY = targetY - titlePainter.height + 1.0;
    final double percentY = targetY + 2.0;

    titlePainter.paint(canvas, Offset(titleX, titleY));
    percentPainter.paint(canvas, Offset(percentX, percentY));
  }

  @override
  bool shouldRepaint(covariant PieChartCalloutPainter oldDelegate) {
    return oldDelegate.touchedIndex != touchedIndex ||
        oldDelegate.totalSpent != totalSpent ||
        oldDelegate.pieRadius != pieRadius ||
        oldDelegate.textColor != textColor ||
        oldDelegate.subtextColor != subtextColor ||
        oldDelegate.startDegreeOffset != startDegreeOffset ||
        oldDelegate.data != data;
  }
}
