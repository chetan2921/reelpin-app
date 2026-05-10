enum SubscriptionPlan {
  free,
  pro;

  static SubscriptionPlan fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'pro':
        return SubscriptionPlan.pro;
      default:
        return SubscriptionPlan.free;
    }
  }
}

enum BillingInterval {
  monthly,
  yearly;

  static BillingInterval? fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'monthly':
        return BillingInterval.monthly;
      case 'yearly':
        return BillingInterval.yearly;
      default:
        return null;
    }
  }
}

enum SubscriptionStatus {
  active,
  canceled,
  pastDue;

  static SubscriptionStatus fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      default:
        return SubscriptionStatus.active;
    }
  }
}

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

class EntitlementFeatures {
  const EntitlementFeatures({
    this.basicAiCategorization = true,
    this.keywordSearch = true,
    this.conversationalRagSearch = false,
    this.mapPins = true,
    this.shareableCollectionLinks = false,
    this.weeklyAiDigest = false,
    this.priorityProcessing = false,
  });

  final bool basicAiCategorization;
  final bool keywordSearch;
  final bool conversationalRagSearch;
  final bool mapPins;
  final bool shareableCollectionLinks;
  final bool weeklyAiDigest;
  final bool priorityProcessing;

  factory EntitlementFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EntitlementFeatures();
    }

    return EntitlementFeatures(
      basicAiCategorization: json['basic_ai_categorization'] == true,
      keywordSearch: json['keyword_search'] == true,
      conversationalRagSearch: json['conversational_rag_search'] == true,
      mapPins: json['map_pins'] == true,
      shareableCollectionLinks: json['shareable_collection_links'] == true,
      weeklyAiDigest: json['weekly_ai_digest'] == true,
      priorityProcessing: json['priority_processing'] == true,
    );
  }
}

class EntitlementLimits {
  const EntitlementLimits({
    this.reelsPerMonth,
    this.accessibleHistoryDays,
    this.mapPins,
  });

  final int? reelsPerMonth;
  final int? accessibleHistoryDays;
  final int? mapPins;

  factory EntitlementLimits.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EntitlementLimits();
    }

    return EntitlementLimits(
      reelsPerMonth: (json['reels_per_month'] as num?)?.toInt(),
      accessibleHistoryDays: (json['accessible_history_days'] as num?)?.toInt(),
      mapPins: (json['map_pins'] as num?)?.toInt(),
    );
  }
}

class EntitlementUsage {
  const EntitlementUsage({
    this.reelsSavedThisMonth = 0,
    this.reelsRemainingThisMonth,
  });

  final int reelsSavedThisMonth;
  final int? reelsRemainingThisMonth;

  factory EntitlementUsage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EntitlementUsage();
    }

    return EntitlementUsage(
      reelsSavedThisMonth:
          (json['reels_saved_this_month'] as num?)?.toInt() ?? 0,
      reelsRemainingThisMonth: (json['reels_remaining_this_month'] as num?)
          ?.toInt(),
    );
  }
}

class UserEntitlement {
  const UserEntitlement({
    required this.userId,
    required this.plan,
    required this.billingInterval,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.searchMode,
    required this.features,
    required this.limits,
    required this.usage,
    required this.pricingInrMonthly,
    required this.pricingInrYearly,
  });

  final String userId;
  final SubscriptionPlan plan;
  final BillingInterval? billingInterval;
  final SubscriptionStatus status;
  final String? currentPeriodStart;
  final String? currentPeriodEnd;
  final SearchMode searchMode;
  final EntitlementFeatures features;
  final EntitlementLimits limits;
  final EntitlementUsage usage;
  final int pricingInrMonthly;
  final int pricingInrYearly;

  factory UserEntitlement.fromJson(Map<String, dynamic> json) {
    return UserEntitlement(
      userId: json['user_id']?.toString() ?? '',
      plan: SubscriptionPlan.fromValue(json['plan']?.toString()),
      billingInterval: BillingInterval.fromValue(
        json['billing_interval']?.toString(),
      ),
      status: SubscriptionStatus.fromValue(json['status']?.toString()),
      currentPeriodStart: json['current_period_start']?.toString(),
      currentPeriodEnd: json['current_period_end']?.toString(),
      searchMode: SearchMode.fromValue(json['search_mode']?.toString()),
      features: EntitlementFeatures.fromJson(
        json['features'] as Map<String, dynamic>?,
      ),
      limits: EntitlementLimits.fromJson(
        json['limits'] as Map<String, dynamic>?,
      ),
      usage: EntitlementUsage.fromJson(json['usage'] as Map<String, dynamic>?),
      pricingInrMonthly: (json['pricing_inr_monthly'] as num?)?.toInt() ?? 149,
      pricingInrYearly: (json['pricing_inr_yearly'] as num?)?.toInt() ?? 999,
    );
  }

  bool get isPro => plan == SubscriptionPlan.pro;
  bool get isFree => !isPro;

  String get planLabel => isPro ? 'PRO' : 'FREE';

  String get searchModeLabel =>
      searchMode == SearchMode.rag ? 'CONVERSATIONAL' : 'KEYWORD';

  String get monthlyPriceLabel => '₹$pricingInrMonthly/month';

  String get yearlyPriceLabel => '₹$pricingInrYearly/year';

  String get contentAccessSignature => [
    plan.name,
    status.name,
    searchMode.name,
    limits.reelsPerMonth?.toString() ?? 'none',
    limits.accessibleHistoryDays?.toString() ?? 'none',
    limits.mapPins?.toString() ?? 'none',
    features.priorityProcessing.toString(),
    features.shareableCollectionLinks.toString(),
    features.weeklyAiDigest.toString(),
  ].join('|');
}
