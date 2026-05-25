class ShareResolveResponse {
  const ShareResolveResponse({
    required this.supported,
    this.extractedUrl,
    this.normalizedUrl,
    this.provider,
    this.errorMessage,
  });

  final bool supported;
  final String? extractedUrl;
  final String? normalizedUrl;
  final String? provider;
  final String? errorMessage;

  factory ShareResolveResponse.fromJson(Map<String, dynamic> json) {
    return ShareResolveResponse(
      supported: json['supported'] == true,
      extractedUrl: json['extracted_url']?.toString(),
      normalizedUrl: json['normalized_url']?.toString(),
      provider: json['provider']?.toString(),
      errorMessage: json['error_message']?.toString(),
    );
  }
}
