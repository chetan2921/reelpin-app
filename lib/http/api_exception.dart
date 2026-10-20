class ApiException implements Exception {
  const ApiException(
    this.message,
    this.statusCode, {
    this.errorCode,
    this.requestId,
    this.details = const {},
    this.retryable = false,
  });

  final String message;
  final int statusCode;
  final String? errorCode;
  final String? requestId;
  final Map<String, dynamic> details;
  final bool retryable;

  bool get isUpgradeRequired => statusCode == 402;

  // Dormant: these are v1 codes. /api/v2 reports plan limits but does not
  // enforce them, so it never sends either; they wake when Go enforces them.
  bool get isMonthlyReelLimitReached =>
      errorCode == 'monthly_reel_limit_reached';
  bool get isHistoryUpgradeRequired => errorCode == 'history_upgrade_required';

  @override
  String toString() => message;
}
