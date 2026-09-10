import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';

/// One colour for every bar by default. A bar per palette colour was tried and
/// read as decoration rather than data; the palette here is tuned once real
/// answers exist.
class ChatChartBlockView extends StatelessWidget {
  const ChatChartBlockView({super.key, required this.block});

  final ChartBlock block;

  static const _height = 150.0;

  /// Reserves two lines of label height, so a long name wraps instead of
  /// bleeding into its neighbour's slot.
  static const _labelReservedSize = 34.0;

  @override
  Widget build(BuildContext context) {
    if (block.bars.isEmpty) return const SizedBox.shrink();

    final maxValue = block.bars
        .map((bar) => bar.value)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.title,
          style: GoogleFonts.spaceMono(
            color: AppColors.textSec(context),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Each bar gets an equal share of the chart's width — matches
              // how BarChart itself spaces the bars — so a label never
              // draws wider than the slot its own bar sits in.
              final slotWidth = constraints.maxWidth / block.bars.length;
              return BarChart(
                BarChartData(
                  maxY: maxValue * 1.15,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: AppColors.fg(context)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _labelReservedSize,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= block.bars.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: slotWidth,
                              child: Text(
                                block.bars[index].label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceMono(
                                  color: AppColors.textSec(context),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(block.bars.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: block.bars[index].value,
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.fg(context)),
                          width: 26,
                        ),
                      ],
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
