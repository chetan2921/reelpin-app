part of '../discover_screen.dart';

class _SavedDateCalendarSheet extends StatefulWidget {
  const _SavedDateCalendarSheet({
    required this.savedDates,
    required this.selectedSavedDate,
  });

  final List<SavedDateOption> savedDates;
  final String? selectedSavedDate;

  @override
  State<_SavedDateCalendarSheet> createState() =>
      _SavedDateCalendarSheetState();
}

class _SavedDateCalendarSheetState extends State<_SavedDateCalendarSheet> {
  late final Map<DateTime, SavedDateOption> _optionsByDay;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _optionsByDay = {
      for (final option in widget.savedDates)
        if (_parseSavedDate(option.value) != null)
          _dayKey(_parseSavedDate(option.value)!): option,
    };

    final selectedDate = _parseSavedDate(widget.selectedSavedDate);
    final latestSavedDate = _optionsByDay.keys.isEmpty
        ? DateTime.now()
        : _optionsByDay.keys.reduce((latest, date) {
            return date.isAfter(latest) ? date : latest;
          });
    final initialDate = selectedDate ?? latestSavedDate;
    _visibleMonth = DateTime(initialDate.year, initialDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final days = _visibleDays();
    final selectedDate = _parseSavedDate(widget.selectedSavedDate);
    final selectedDay = selectedDate == null ? null : _dayKey(selectedDate);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          layout.inset(20),
          layout.gap(18),
          layout.inset(20),
          layout.gap(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SAVED DATES',
                    style: GoogleFonts.spaceMono(
                      color: AppColors.fg(context),
                      fontSize: layout.font(18),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: layout.inset(36),
                    height: layout.inset(36),
                    decoration: AppTheme.brutalBox(context, shadow: true),
                    child: Icon(
                      Icons.close,
                      color: AppColors.fg(context),
                      size: layout.inset(18),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: layout.gap(16)),
            Container(
              decoration: AppTheme.brutalBox(context, shadow: true),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(layout.inset(12)),
                    child: Row(
                      children: [
                        _monthButton(
                          context,
                          icon: Icons.chevron_left,
                          onTap: _showPreviousMonth,
                        ),
                        Expanded(
                          child: Text(
                            _monthLabel(_visibleMonth).toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.fg(context),
                              fontSize: layout.font(13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _monthButton(
                          context,
                          icon: Icons.chevron_right,
                          onTap: _showNextMonth,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: AppTheme.thinBorderWidth,
                    thickness: AppTheme.thinBorderWidth,
                    color: AppColors.fg(context),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.inset(10),
                      layout.gap(10),
                      layout.inset(10),
                      layout.gap(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            _WeekdayLabel(label: 'S'),
                            _WeekdayLabel(label: 'M'),
                            _WeekdayLabel(label: 'T'),
                            _WeekdayLabel(label: 'W'),
                            _WeekdayLabel(label: 'T'),
                            _WeekdayLabel(label: 'F'),
                            _WeekdayLabel(label: 'S'),
                          ],
                        ),
                        SizedBox(height: layout.gap(8)),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: days.length,
                          itemBuilder: (context, index) {
                            return _buildDayCell(
                              context,
                              day: days[index],
                              selectedDay: selectedDay,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final layout = AppLayout.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: layout.inset(32),
        height: layout.inset(32),
        decoration: AppTheme.brutalBox(context, shadow: false),
        child: Icon(icon, color: AppColors.fg(context), size: layout.inset(18)),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context, {
    required DateTime? day,
    required DateTime? selectedDay,
  }) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final layout = AppLayout.of(context);
    final key = _dayKey(day);
    final option = _optionsByDay[key];
    final hasSavedReels = option != null;
    final isSelected = selectedDay == key;
    final isCurrentMonth =
        day.year == _visibleMonth.year && day.month == _visibleMonth.month;
    final backgroundColor = isSelected
        ? AppColors.yellow
        : hasSavedReels
        ? AppColors.hotPink
        : AppColors.bg(context);
    final textColor = isSelected || hasSavedReels
        ? AppColors.black
        : isCurrentMonth
        ? AppColors.fg(context)
        : AppColors.textSec(context);

    return GestureDetector(
      onTap: hasSavedReels ? () => Navigator.pop(context, option) : null,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: hasSavedReels || isSelected
                ? AppColors.fg(context)
                : AppColors.textSec(context),
            width: hasSavedReels || isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${day.day}',
                style: GoogleFonts.spaceMono(
                  color: textColor,
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hasSavedReels)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen,
                    border: Border.all(color: AppColors.fg(context), width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<DateTime?> _visibleDays() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlankCount = firstOfMonth.weekday % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < leadingBlankCount; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_visibleMonth.year, _visibleMonth.month, day),
    ];

    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    while (cells.length < 42) {
      cells.add(null);
    }
    return cells;
  }

  void _showPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _showNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static DateTime? _parseSavedDate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    return _dayKey(parsed);
  }

  static DateTime _dayKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.spaceMono(
          color: AppColors.textSec(context),
          fontSize: layout.font(10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
