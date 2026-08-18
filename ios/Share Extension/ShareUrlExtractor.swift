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
  case invalidShareToken
  case failure
}

struct ShareResponseClassifier {
  static func classify(statusCode: Int, data: Data?) -> ShareRequestResult {
    if (200...299).contains(statusCode) {
      return .success
    }

    let responseBody = data.flatMap { String(data: $0, encoding: .utf8) }?.lowercased()
    if (statusCode == 401 || statusCode == 403),
       responseBody?.contains("invalid_share_token") == true {
      return .invalidShareToken
    }
    return .failure
  }
}
