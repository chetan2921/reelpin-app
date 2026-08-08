part of '../home_screen.dart';

/// One row in a filter dropdown. [value] is what the API is asked for and
/// [label] is what the user reads — they differ because the backend derives
/// display labels from the stored value.
class _FilterOption {
  final String value;
  final String label;
  final int count;
  final Color accentColor;

  const _FilterOption({
    required this.value,
    required this.label,
    required this.count,
    required this.accentColor,
  });
}
