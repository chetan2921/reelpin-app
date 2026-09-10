enum ThinkingStageState { pending, active, done }

/// One line of the "how the answer is being built" list. These are shown while
/// waiting and discarded once the answer arrives — they are never persisted.
class ThinkingStage {
  final String label;
  final ThinkingStageState state;

  const ThinkingStage({required this.label, required this.state});

  ThinkingStage copyWith({ThinkingStageState? state}) =>
      ThinkingStage(label: label, state: state ?? this.state);
}
