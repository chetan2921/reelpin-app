class ApiException implements Exception {
  const ApiException(
    this.message,
    this.statusCode, {
    this.errorCode,
    this.detail,
    this.retryable = false,
  });

  final String message;
  final int statusCode;
  final String? errorCode;
  final String? detail;
  final bool retryable;

  bool get isUpgradeRequired => statusCode == 402;
  bool get isMonthlyReelLimitReached =>
      errorCode == 'monthly_reel_limit_reached';
  bool get isHistoryUpgradeRequired => errorCode == 'history_upgrade_required';

  /// The backend's daily free chat allowance is spent; the app offers Pro.
  bool get isChatQuotaExceeded => errorCode == 'chat_quota_exceeded';

  /// A Pro user's daily fair-use chat cap is spent; it resets at midnight IST.
  bool get isChatFairUseLimit => errorCode == 'chat_fair_use_limit';

  @override
  String toString() => message;
}
