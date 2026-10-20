class ShareResolveResponse {
  const ShareResolveResponse({
    required this.supported,
    this.url,
    this.sourcePlatform,
    this.sourceContentType,
  });

  final bool supported;
  final String? url;
  final String? sourcePlatform;
  final String? sourceContentType;

  factory ShareResolveResponse.fromJson(Map<String, dynamic> json) {
    return ShareResolveResponse(
      supported: json['supported'] == true,
      url: json['url']?.toString(),
      sourcePlatform: json['source_platform']?.toString(),
      sourceContentType: json['source_content_type']?.toString(),
    );
  }
}
