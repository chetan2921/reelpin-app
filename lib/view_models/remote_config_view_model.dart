import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/app_config/remote_config.dart';
import 'package:reelpin/services/device_metadata_service.dart';
import 'package:reelpin/services/remote_config/remote_config_service.dart';

/// The remote switches as the UI reads them: whether this build must update,
/// which announcement is owed, and whether the paywall may be offered.
///
/// Until a document arrives every answer is the open one (no gate, no
/// announcement, paywall hidden), and a launch never waits on the network for
/// it. The cached copy usually lands within a frame or two; a fresh fetch
/// replaces it when it lands, at most [RemoteConfigService.timeout] later.
class RemoteConfigViewModel extends ChangeNotifier {
  RemoteConfigViewModel(
    this._service, {
    Future<int?> Function()? loadBuildNumber,
  }) : _loadBuildNumber = loadBuildNumber ?? _nativeBuildNumber;

  final RemoteConfigService _service;
  final Future<int?> Function() _loadBuildNumber;

  RemoteConfig _config = const RemoteConfig();
  int? _buildNumber;
  bool _hasStarted = false;
  bool _updateNudgeTaken = false;
  final Set<String> _announcementsTaken = {};
  Future<void>? _inFlightRefresh;

  bool get paywallVisible => _config.paywallVisible;

  /// The update this build is below, or null. An unknown build number is never
  /// gated: a hard block on a build we cannot read would lock everyone out.
  UpdateRequirement? get requiredUpdate {
    final build = _buildNumber;
    if (build == null) return null;
    final requirement = _config.updateRequired;
    return requirement.appliesTo(defaultTargetPlatform, build)
        ? requirement
        : null;
  }

  UpdateRequirement? get blockingUpdate {
    final requirement = requiredUpdate;
    return requirement != null && requirement.hard ? requirement : null;
  }

  Future<void> start() async {
    if (_hasStarted) return;
    _hasStarted = true;
    if (!_service.isEnabled) return;

    _buildNumber = await _loadBuildNumber();
    final cached = await _service.readCached();
    if (cached != null) {
      _config = cached;
      notifyListeners();
    }
    await refresh();
  }

  /// Safe to call on every resume: the service skips the request while the
  /// last fetch is under an hour old, and overlapping calls share one request.
  Future<void> refresh() {
    if (!_hasStarted || !_service.isEnabled) return Future.value();
    return _inFlightRefresh ??= _refresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<void> _refresh() async {
    final fresh = await _service.fetchIfDue();
    if (fresh == null) return;
    _config = fresh;
    notifyListeners();
  }

  /// The soft update nudge, handed out once per app session.
  UpdateRequirement? takeUpdateNudge() {
    final requirement = requiredUpdate;
    if (requirement == null || requirement.hard || _updateNudgeTaken) {
      return null;
    }
    _updateNudgeTaken = true;
    return requirement;
  }

  /// The configured announcement if it is owed: once per id for good when
  /// `show_once` is set, otherwise once per app session.
  Future<FeatureAnnouncement?> takeAnnouncement() async {
    final announcement = _config.featureAnnouncement;
    if (!announcement.isShowable) return null;
    // Claimed before the await so two callers cannot both show it.
    if (!_announcementsTaken.add(announcement.id)) return null;
    if (!announcement.showOnce) return announcement;
    if (await _service.wasAnnouncementShown(announcement.id)) return null;
    await _service.markAnnouncementShown(announcement.id);
    return announcement;
  }

  static Future<int?> _nativeBuildNumber() async {
    final metadata = await const DeviceMetadataService().load();
    final build = int.tryParse(metadata.appBuild);
    // The metadata fallback reports build "0" off-device or when the channel
    // fails; treat that as unknown rather than as an ancient build.
    return build != null && build > 0 ? build : null;
  }
}
