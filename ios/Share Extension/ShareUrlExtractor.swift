import Foundation

struct ShareUrlExtractor {
  private static let urlCandidatePattern = #"https?://[^\s<>"']+"#
  private static let trailingPunctuation = Set<Character>([".", ",", "!", "?", ";", ":", ")", "]", "}", "\""])

  static func extractSupportedUrl(from text: String) -> String? {
    guard
      let regex = try? NSRegularExpression(
        pattern: urlCandidatePattern,
        options: [.caseInsensitive]
      )
    else {
      return nil
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    for match in regex.matches(in: text, options: [], range: range) {
      guard let matchRange = Range(match.range, in: text) else {
        continue
      }
      let candidate = trimTrailingPunctuation(String(text[matchRange]))
      if isSupportedUrl(candidate) {
        return candidate
      }
    }
    return nil
  }

  /// Which platforms are supported is the backend's decision: the enqueue
  /// endpoint rejects unsupported URLs with a specific message. Keeping an
  /// allowlist here too only meant a new platform needed an app release.
  private static func isSupportedUrl(_ value: String) -> Bool {
    guard
      let components = URLComponents(string: value),
      let host = components.host?.lowercased(),
      !host.isEmpty,
      let scheme = components.scheme?.lowercased()
    else {
      return false
    }

    return scheme == "http" || scheme == "https"
  }

  private static func trimTrailingPunctuation(_ value: String) -> String {
    var result = value
    while let last = result.last, trailingPunctuation.contains(last) {
      result.removeLast()
    }
    return result
  }
}

enum ShareRequestResult: Equatable {
  case success
  case alreadySaved
  case invalidShareToken
  case failure
}

/// 200 (reel already saved) and 202 (job queued or in flight) are both a save; every v2
/// failure is the `{"error": {"code", ...}}` envelope.
struct ShareResponseClassifier {
  private static let shareTokenErrors: Set<String> = ["invalid_share_token", "share_token_required"]

  static func classify(statusCode: Int, data: Data?) -> ShareRequestResult {
    if statusCode == 200 {
      return .alreadySaved
    }

    if (201...299).contains(statusCode) {
      return .success
    }

    if statusCode == 401, let code = errorCode(from: data), shareTokenErrors.contains(code) {
      return .invalidShareToken
    }
    return .failure
  }

  private static func errorCode(from data: Data?) -> String? {
    guard
      let data,
      let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let error = body["error"] as? [String: Any]
    else {
      return nil
    }
    return error["code"] as? String
  }
}
