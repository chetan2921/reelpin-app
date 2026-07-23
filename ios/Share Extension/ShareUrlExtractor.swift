import Foundation

struct ShareUrlExtractor {
  private static let urlCandidatePattern = #"https?://[^\s<>"']+"#
  private static let videoIdPattern = #"^[A-Za-z0-9_-]+$"#
  private static let tiktokPathPattern = #"^[A-Za-z0-9@._/\-]+$"#
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

  private static func isSupportedUrl(_ value: String) -> Bool {
    guard
      let components = URLComponents(string: value),
      let host = components.host?.lowercased(),
      !host.isEmpty
    else {
      return false
    }

    return isInstagramUrl(components, host: host) ||
      isTikTokUrl(components, host: host) ||
      isYoutubeUrl(components, host: host) ||
      isXUrl(host: host)
  }

  private static func isInstagramUrl(_ components: URLComponents, host: String) -> Bool {
    guard host == "instagram.com" || host == "www.instagram.com" else {
      return false
    }
    let segments = pathSegments(components)
    guard segments.count >= 2 else {
      return false
    }

    let contentType = segments[0].lowercased()
    return (contentType == "reel" || contentType == "p" || contentType == "tv") &&
      matches(segments[1], pattern: videoIdPattern)
  }

  private static func isTikTokUrl(_ components: URLComponents, host: String) -> Bool {
    guard host == "tiktok.com" || host == "vt.tiktok.com" || host == "vm.tiktok.com" else {
      return false
    }
    let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return !path.isEmpty && matches(path, pattern: tiktokPathPattern)
  }

  private static func isYoutubeUrl(_ components: URLComponents, host: String) -> Bool {
    let segments = pathSegments(components)
    if host == "youtu.be" {
      return segments.first.map { matches($0, pattern: videoIdPattern) } == true
    }
    guard host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" else {
      return false
    }
    if segments.count >= 2 &&
      segments[0].lowercased() == "shorts" &&
      matches(segments[1], pattern: videoIdPattern) {
      return true
    }
    return components.path.lowercased() == "/watch" &&
      components.queryItems?.first { $0.name.lowercased() == "v" }
        .flatMap(\.value)
        .map { matches($0, pattern: videoIdPattern) } == true
  }

  private static func isXUrl(host: String) -> Bool {
    let normalizedHost = withoutMobileOrWebPrefix(host)
    return normalizedHost == "x.com" ||
      normalizedHost == "twitter.com" ||
      normalizedHost == "t.co"
  }

  private static func withoutMobileOrWebPrefix(_ host: String) -> String {
    for prefix in ["www.", "mobile.", "m."] where host.hasPrefix(prefix) {
      return String(host.dropFirst(prefix.count))
    }
    return host
  }

  private static func pathSegments(_ components: URLComponents) -> [String] {
    components.path
      .split(separator: "/")
      .map(String.init)
      .filter { !$0.isEmpty }
  }

  private static func matches(_ value: String, pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
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
