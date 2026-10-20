enum SearchMode {
  keyword,
  rag;

  static SearchMode fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'rag':
        return SearchMode.rag;
      default:
        return SearchMode.keyword;
    }
  }
}

/// A plan's ceilings. Null is unlimited.
class EntitlementLimits {
  const EntitlementLimits({
    this.savedReels,
    this.pinnedLocations,
    this.searchesPerMonth,
    this.processingJobsPerHour,
  });

  final int? savedReels;
  final int? pinnedLocations;
  final int? searchesPerMonth;
  final int? processingJobsPerHour;

  factory EntitlementLimits.fromJson(Map<String, dynamic> json) {
    return EntitlementLimits(
      savedReels: (json['saved_reels'] as num?)?.toInt(),
      pinnedLocations: (json['pinned_locations'] as num?)?.toInt(),
      searchesPerMonth: (json['searches_per_month'] as num?)?.toInt(),
      processingJobsPerHour: (json['processing_jobs_per_hour'] as num?)
          ?.toInt(),
    );
  }
}

/// Lifetime totals, not a monthly window.
class EntitlementUsage {
  const EntitlementUsage({
    this.savedReels = 0,
    this.pinnedLocations = 0,
    this.tags = 0,
    this.categories = 0,
    this.subcategories = 0,
  });

  final int savedReels;
  final int pinnedLocations;
  final int tags;
  final int categories;
  final int subcategories;

  factory EntitlementUsage.fromJson(Map<String, dynamic> json) {
    return EntitlementUsage(
      savedReels: (json['saved_reels'] as num?)?.toInt() ?? 0,
      pinnedLocations: (json['pinned_locations'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as num?)?.toInt() ?? 0,
      categories: (json['categories'] as num?)?.toInt() ?? 0,
      subcategories: (json['subcategories'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserEntitlement {
  const UserEntitlement({
    required this.userId,
    required this.plan,
    required this.subscriptionStatus,
    required this.isPremium,
    required this.restricted,
    this.billingInterval,
    this.errorMessage,
  });

  final String userId;

  /// `free`, `pro`, or `restricted` when the plan could not be verified.
  final String plan;
  final String? billingInterval;
  final String subscriptionStatus;
  final bool isPremium;
  final bool restricted;
  final String? errorMessage;

  factory UserEntitlement.fromJson(
    Map<String, dynamic> json, {
    required String userId,
  }) {
    return UserEntitlement(
      userId: userId,
      plan: json['plan']?.toString() ?? '',
      billingInterval: json['billing_interval']?.toString(),
      subscriptionStatus: json['subscription_status']?.toString() ?? '',
      isPremium: json['is_premium'] == true,
      restricted: json['restricted'] == true,
      errorMessage: json['error_message']?.toString(),
    );
  }

  bool get isPro => isPremium && !restricted;
  bool get isFree => !isPro;
}

class PlanCard {
  const PlanCard({
    required this.plan,
    required this.name,
    required this.price,
    required this.features,
    required this.limits,
    this.billingInterval,
    this.ctaLabel,
  });

  final String plan;
  final String name;
  final String price;
  final List<String> features;
  final EntitlementLimits limits;
  final String? billingInterval;
  final String? ctaLabel;

  factory PlanCard.fromJson(Map<String, dynamic> json) {
    return PlanCard(
      plan: json['plan']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      limits: EntitlementLimits.fromJson(_map(json['limits'])),
      billingInterval: json['billing_interval']?.toString(),
      ctaLabel: json['cta_label']?.toString(),
    );
  }
}

class EntitlementsResponse {
  const EntitlementsResponse({
    required this.currentEntitlement,
    required this.usage,
    required this.limits,
    required this.features,
    required this.pricing,
    required this.planCards,
    required this.paywallMessages,
  });

  final UserEntitlement currentEntitlement;
  final EntitlementUsage usage;
  final EntitlementLimits limits;
  final Map<String, bool> features;
  final Map<String, String> pricing;
  final List<PlanCard> planCards;

  /// Paywall copy keyed by where the paywall was opened from: `account`,
  /// `save_limit`, `history`.
  final Map<String, String> paywallMessages;

  factory EntitlementsResponse.fromJson(Map<String, dynamic> json) {
    return EntitlementsResponse(
      currentEntitlement: UserEntitlement.fromJson(
        _map(json['current_entitlement']),
        userId: json['user_id']?.toString() ?? '',
      ),
      usage: EntitlementUsage.fromJson(_map(json['usage'])),
      limits: EntitlementLimits.fromJson(_map(json['limits'])),
      features: {
        for (final entry in _map(json['features']).entries)
          entry.key: entry.value == true,
      },
      pricing: {
        for (final entry in _map(json['pricing']).entries)
          entry.key: '${entry.value}',
      },
      planCards: (json['plan_cards'] as List<dynamic>? ?? const [])
          .map((row) => PlanCard.fromJson(_map(row)))
          .toList(growable: false),
      paywallMessages: {
        for (final entry in _map(json['paywall_messages']).entries)
          entry.key: '${entry.value}',
      },
    );
  }

  String contentAccessSignature() {
    final featureKeys = features.keys.toList()..sort();
    return [
      currentEntitlement.userId,
      currentEntitlement.plan,
      currentEntitlement.subscriptionStatus,
      currentEntitlement.restricted.toString(),
      // Usage counters are deliberately absent. They tick on every save, and
      // including them made each save look like an access change — which wipes
      // and refetches every visible tab. What the user may see is governed by
      // the plan, status and limits below, not by how much of it they have used.
      limits.savedReels?.toString() ?? '',
      limits.pinnedLocations?.toString() ?? '',
      limits.searchesPerMonth?.toString() ?? '',
      limits.processingJobsPerHour?.toString() ?? '',
      for (final key in featureKeys) '$key=${features[key]}',
    ].join('|');
  }

  /// The message for [entryPoint], or any message when that one is missing.
  String? messageFor(String entryPoint) {
    return paywallMessages[entryPoint] ??
        (paywallMessages.isEmpty ? null : paywallMessages.values.first);
  }
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : const {};
}
