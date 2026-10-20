import 'package:flutter/foundation.dart';

/// The remote switches document. Every key is optional, and a key that is
/// missing or of the wrong type reads as its closed default, so a half-written
/// document can never gate the app by accident.
class RemoteConfig {
  const RemoteConfig({
    this.updateRequired = const UpdateRequirement(),
    this.featureAnnouncement = const FeatureAnnouncement(),
    this.paywallVisible = false,
  });

  final UpdateRequirement updateRequired;
  final FeatureAnnouncement featureAnnouncement;
  final bool paywallVisible;

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      updateRequired: UpdateRequirement.fromJson(
        _objectOf(json['update_required']),
      ),
      featureAnnouncement: FeatureAnnouncement.fromJson(
        _objectOf(json['feature_announcement']),
      ),
      paywallVisible: json['paywall_visible'] == true,
    );
  }
}

class UpdateRequirement {
  const UpdateRequirement({
    this.enabled = false,
    this.minBuildIos,
    this.minBuildAndroid,
    this.hard = false,
    this.title = '',
    this.body = '',
    this.storeUrlIos = '',
    this.storeUrlAndroid = '',
  });

  final bool enabled;
  final int? minBuildIos;
  final int? minBuildAndroid;
  final bool hard;
  final String title;
  final String body;
  final String storeUrlIos;
  final String storeUrlAndroid;

  factory UpdateRequirement.fromJson(Map<String, dynamic> json) {
    final minBuild = _objectOf(json['min_build']);
    final storeUrl = _objectOf(json['store_url']);
    return UpdateRequirement(
      enabled: json['enabled'] == true,
      minBuildIos: _intOf(minBuild['ios']),
      minBuildAndroid: _intOf(minBuild['android']),
      hard: json['hard'] == true,
      title: _stringOf(json['title']),
      body: _stringOf(json['body']),
      storeUrlIos: _stringOf(storeUrl['ios']),
      storeUrlAndroid: _stringOf(storeUrl['android']),
    );
  }

  /// A platform with no minimum is never gated.
  bool appliesTo(TargetPlatform platform, int build) {
    if (!enabled) return false;
    final minimum = switch (platform) {
      TargetPlatform.iOS => minBuildIos,
      TargetPlatform.android => minBuildAndroid,
      _ => null,
    };
    return minimum != null && build < minimum;
  }

  String storeUrlFor(TargetPlatform platform) {
    return platform == TargetPlatform.iOS ? storeUrlIos : storeUrlAndroid;
  }
}

class FeatureAnnouncement {
  const FeatureAnnouncement({
    this.enabled = false,
    this.id = '',
    this.title = '',
    this.body = '',
    this.showOnce = false,
  });

  final bool enabled;
  final String id;
  final String title;
  final String body;
  final bool showOnce;

  factory FeatureAnnouncement.fromJson(Map<String, dynamic> json) {
    return FeatureAnnouncement(
      enabled: json['enabled'] == true,
      id: _stringOf(json['id']),
      title: _stringOf(json['title']),
      body: _stringOf(json['body']),
      showOnce: json['show_once'] == true,
    );
  }

  /// The id is what remembers that it was shown, so one without an id would
  /// come back on every launch.
  bool get isShowable => enabled && id.isNotEmpty;
}

Map<String, dynamic> _objectOf(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : const {};
}

String _stringOf(Object? value) => value is String ? value.trim() : '';

int? _intOf(Object? value) => value is num ? value.toInt() : null;
