import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reelpin/constants/app_colors.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';

/// Columns come from the question, not a fixed schema, so the width is unknown
/// and the table scrolls sideways inside the answer rather than wrapping.
class ChatTableBlockView extends StatelessWidget {
  const ChatTableBlockView({super.key, required this.block});

  final TableBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.columns.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: AppColors.fg(context)),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.yellow),
            children: block.columns
                .map((column) => _cell(column, bold: true, onYellow: true))
                .toList(),
          ),
          ...block.rows.map(
            (row) => TableRow(
              children: [
                for (var i = 0; i < block.columns.length; i++)
                  _cell(
                    i < row.length ? row[i] : '',
                    color: AppColors.fg(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    String text, {
    bool bold = false,
    bool onYellow = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Text(
        text,
        style: GoogleFonts.spaceMono(
          color: onYellow ? AppColors.black : color,
          fontSize: 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: bold ? 1 : 0,
        ),
      ),
    );
  }
}
