import XCTest

class RunnerTests: XCTestCase {
  func testExtractsYoutubeUrls() {
    let cases = [
      "https://www.youtube.com/shorts/VIDEO_ID":
        "https://www.youtube.com/shorts/VIDEO_ID",
      "https://youtube.com/shorts/VIDEO_ID":
        "https://youtube.com/shorts/VIDEO_ID",
      "https://youtu.be/VIDEO_ID":
        "https://youtu.be/VIDEO_ID",
      "https://m.youtube.com/shorts/VIDEO_ID":
        "https://m.youtube.com/shorts/VIDEO_ID",
      "https://www.youtube.com/watch?v=VIDEO_ID":
        "https://www.youtube.com/watch?v=VIDEO_ID",
      "https://www.youtube.com/shorts/VIDEO_ID?si=abc123":
        "https://www.youtube.com/shorts/VIDEO_ID?si=abc123",
      "Check this out https://www.youtube.com/shorts/VIDEO_ID?si=abc123":
        "https://www.youtube.com/shorts/VIDEO_ID?si=abc123",
    ]

    for (payload, expected) in cases {
      XCTAssertEqual(ShareUrlExtractor.extractSupportedUrl(from: payload), expected)
    }
  }

  func testExtractsMobileYoutubeWatchUrlsWithExtraQueryParams() {
    let url = "https://m.youtube.com/watch?v=VIDEO_ID&feature=share&utm_source=x"

    XCTAssertEqual(ShareUrlExtractor.extractSupportedUrl(from: url), url)
  }

  func testKeepsInstagramExtractionUnchanged() {
    XCTAssertEqual(
      ShareUrlExtractor.extractSupportedUrl(
        from: "Saved this https://www.instagram.com/reel/abc_123/?utm_source=ig"
      ),
      "https://www.instagram.com/reel/abc_123/?utm_source=ig"
    )
  }

  func testIgnoresUnsupportedUrls() {
    XCTAssertNil(ShareUrlExtractor.extractSupportedUrl(from: "https://example.com/video/123"))
  }

  func testExtractsXUrlsWithoutValidatingTheirPaths() {
    let cases = [
      "https://x.com/OpenAI/status/1234567890":
        "https://x.com/OpenAI/status/1234567890",
      "https://twitter.com/OpenAI/status/1234567890?s=20&utm_source=share":
        "https://twitter.com/OpenAI/status/1234567890?s=20&utm_source=share",
      "https://mobile.twitter.com/OpenAI/status/1234567890":
        "https://mobile.twitter.com/OpenAI/status/1234567890",
      "https://x.com/i/web/status/1234567890":
        "https://x.com/i/web/status/1234567890",
      "https://t.co/AbCdEf123":
        "https://t.co/AbCdEf123",
      "Check this post https://x.com/OpenAI/status/1234567890?s=20":
        "https://x.com/OpenAI/status/1234567890?s=20",
      "https://MoBiLe.TwItTeR.CoM/OpenAI/status/1234567890":
        "https://MoBiLe.TwItTeR.CoM/OpenAI/status/1234567890",
      "https://x.com/OpenAI/status/not-a-number":
        "https://x.com/OpenAI/status/not-a-number",
      "https://x.com/OpenAI":
        "https://x.com/OpenAI",
    ]

    for (payload, expected) in cases {
      XCTAssertEqual(ShareUrlExtractor.extractSupportedUrl(from: payload), expected)
    }
  }

  func testRejectsXLookalikeDomains() {
    XCTAssertNil(
      ShareUrlExtractor.extractSupportedUrl(
        from: "https://x.com.example.com/OpenAI/status/1234567890"
      )
    )
  }

  func testClassifiesExpiredShareTokens() {
    let invalidToken = #"{"error_code":"invalid_share_token"}"#.data(using: .utf8)
    let otherFailure = #"{"error_code":"invalid_url"}"#.data(using: .utf8)

    XCTAssertEqual(
      ShareResponseClassifier.classify(statusCode: 401, data: invalidToken),
      .invalidShareToken
    )
    XCTAssertEqual(
      ShareResponseClassifier.classify(statusCode: 401, data: otherFailure),
      .failure
    )
  }
}
