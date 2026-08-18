part of '../profile_screen.dart';

/// Whether a share into ReelPin pauses to offer collections.
///
/// On by default — filing at share time is the whole point of the picker — but
/// someone who never files a reel pays an extra tap for every save, so it can
/// be turned off to restore the straight-to-library behaviour.
class _SharePickerPreferenceCard extends ConsumerStatefulWidget {
  const _SharePickerPreferenceCard();

  @override
  ConsumerState<_SharePickerPreferenceCard> createState() =>
      _SharePickerPreferenceCardState();
}

class _SharePickerPreferenceCardState
    extends ConsumerState<_SharePickerPreferenceCard> {
  bool _enabled = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final enabled = await ShareHandoffService.instance
        .isCollectionPickerEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _set(bool enabled) async {
    if (_isUpdating) return;
    setState(() {
      _enabled = enabled;
      _isUpdating = true;
    });
    try {
      await ShareHandoffService.instance.setCollectionPickerEnabled(
        enabled,
        ref.read(collectionsViewModelProvider).collections,
        renderTiles: CollectionTileRenderer.writeTiles,
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileActionCard(
      title: 'SHOW COLLECTIONS WHEN SHARING',
      subtitle: _enabled
          ? 'SHARING INTO REELPIN ASKS WHICH COLLECTION TO FILE IT IN.'
          : 'SHARING INTO REELPIN SAVES STRAIGHT TO YOUR LIBRARY.',
      trailing: AppSwitch(
        value: _enabled,
        onChanged: _isUpdating ? null : _set,
      ),
    );
  }
}
