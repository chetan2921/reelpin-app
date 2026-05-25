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
    this.basicAiCategorization = false,
    this.keywordSearch = false,
    this.conversationalRagSearch = false,
    this.mapPins = false,
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

class EntitlementPricing {
  const EntitlementPricing({this.monthlyLabel = '', this.yearlyLabel = ''});

  final String monthlyLabel;
  final String yearlyLabel;

  factory EntitlementPricing.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EntitlementPricing();
    }

    return EntitlementPricing(
      monthlyLabel:
          json['monthly_label']?.toString() ??
          json['pricing_inr_monthly_label']?.toString() ??
          '',
      yearlyLabel:
          json['yearly_label']?.toString() ??
          json['pricing_inr_yearly_label']?.toString() ??
          '',
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
    required this.restricted,
    required this.planLabel,
    required this.searchModeLabel,
  });

  final String userId;
  final SubscriptionPlan plan;
  final BillingInterval? billingInterval;
  final SubscriptionStatus status;
  final String? currentPeriodStart;
  final String? currentPeriodEnd;
  final SearchMode searchMode;
  final bool restricted;
  final String planLabel;
  final String searchModeLabel;

  factory UserEntitlement.fromJson(Map<String, dynamic> json) {
    final plan = SubscriptionPlan.fromValue(json['plan']?.toString());
    final searchMode = SearchMode.fromValue(json['search_mode']?.toString());
    return UserEntitlement(
      userId: json['user_id']?.toString() ?? '',
      plan: plan,
      billingInterval: BillingInterval.fromValue(
        json['billing_interval']?.toString(),
      ),
      status: SubscriptionStatus.fromValue(json['status']?.toString()),
      currentPeriodStart: json['current_period_start']?.toString(),
      currentPeriodEnd: json['current_period_end']?.toString(),
      searchMode: searchMode,
      restricted: json['restricted'] == true,
      planLabel: json['plan_label']?.toString() ?? plan.name.toUpperCase(),
      searchModeLabel:
          json['search_mode_label']?.toString() ??
          searchMode.name.toUpperCase(),
    );
  }

  bool get isPro => plan == SubscriptionPlan.pro && !restricted;
  bool get isFree => !isPro;
}

class PlanCard {
  const PlanCard({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.features,
    this.badgeLabel,
    this.ctaLabel,
  });

  final String id;
  final String title;
  final String priceLabel;
  final List<String> features;
  final String? badgeLabel;
  final String? ctaLabel;

  factory PlanCard.fromJson(Map<String, dynamic> json) {
    return PlanCard(
      id: json['id']?.toString() ?? json['plan']?.toString() ?? '',
      title: json['title']?.toString() ?? json['label']?.toString() ?? '',
      priceLabel:
          json['price_label']?.toString() ?? json['price']?.toString() ?? '',
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      badgeLabel: json['badge_label']?.toString(),
      ctaLabel: json['cta_label']?.toString(),
    );
  }
}

class PaywallMessage {
  const PaywallMessage({
    required this.entryPoint,
    required this.title,
    required this.headline,
    required this.body,
  });

  final String entryPoint;
  final String title;
  final String headline;
  final String body;

  factory PaywallMessage.fromJson(Map<String, dynamic> json) {
    return PaywallMessage(
      entryPoint: json['entry_point']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      body:
          json['body']?.toString() ??
          json['supporting_text']?.toString() ??
          json['message']?.toString() ??
          '',
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
  final EntitlementFeatures features;
  final EntitlementPricing pricing;
  final List<PlanCard> planCards;
  final List<PaywallMessage> paywallMessages;

  factory EntitlementsResponse.fromJson(Map<String, dynamic> json) {
    final current = json['current_entitlement'] is Map
        ? Map<String, dynamic>.from(json['current_entitlement'] as Map)
        : json;

    return EntitlementsResponse(
      currentEntitlement: UserEntitlement.fromJson(current),
      usage: EntitlementUsage.fromJson(
        Map<String, dynamic>.from(json['usage'] as Map? ?? const {}),
      ),
      limits: EntitlementLimits.fromJson(
        Map<String, dynamic>.from(json['limits'] as Map? ?? const {}),
      ),
      features: EntitlementFeatures.fromJson(
        Map<String, dynamic>.from(json['features'] as Map? ?? const {}),
      ),
      pricing: EntitlementPricing.fromJson(
        Map<String, dynamic>.from(json['pricing'] as Map? ?? const {}),
      ),
      planCards: (json['plan_cards'] as List<dynamic>? ?? const [])
          .map(
            (row) => PlanCard.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false),
      paywallMessages: (json['paywall_messages'] as List<dynamic>? ?? const [])
          .map(
            (row) =>
                PaywallMessage.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false),
    );
  }

  String contentAccessSignature() {
    return [
      currentEntitlement.userId,
      currentEntitlement.plan.name,
      currentEntitlement.status.name,
      currentEntitlement.searchMode.name,
      currentEntitlement.restricted.toString(),
      usage.reelsSavedThisMonth.toString(),
      usage.reelsRemainingThisMonth?.toString() ?? '',
      limits.reelsPerMonth?.toString() ?? '',
      limits.accessibleHistoryDays?.toString() ?? '',
      limits.mapPins?.toString() ?? '',
      features.conversationalRagSearch.toString(),
      features.priorityProcessing.toString(),
      features.shareableCollectionLinks.toString(),
      features.weeklyAiDigest.toString(),
    ].join('|');
  }

  PaywallMessage? messageFor(String entryPoint) {
    for (final message in paywallMessages) {
      if (message.entryPoint.trim().toLowerCase() ==
          entryPoint.trim().toLowerCase()) {
        return message;
      }
    }
    return paywallMessages.isNotEmpty ? paywallMessages.first : null;
  }
}
