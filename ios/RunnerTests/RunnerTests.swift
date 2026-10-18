import XCTest

class RunnerTests: XCTestCase {
  func testTikTokShareVariantsKeepTheirPayloadAndParameters() {
    let urls = [
      "https://www.tiktok.com/@creator/video/123?_t=share",
      "https://www.tiktok.com/@creator/photo/123",
      "https://vm.tiktok.com/ABC/",
      "https://vt.tiktok.com/ABC/",
      "https://www.tiktok.com/t/ABC/",
      "https://www.tiktok.com/@/video/123",
      "https://www.tiktok.com/share/video/123",
      "https://www.tiktokv.com/share/video/123",
      "https://m.tiktok.com/v/123.html",
      "https://www.tiktok.com/embed/123",
      "https://www.tiktok.com/player/v1/123",
      "https://www.tiktok.com/@creator/live",
      "https://www.tiktok.com/tag/food",
      "https://shop.tiktok.com/product/123",
    ]
    for url in urls {
      XCTAssertEqual(ShareUrlExtractor.extractSupportedUrl(from: "Watch this \(url)."), url)
    }
  }

  func testAcceptsAnyHttpLinkWhateverTheHost() {
    let cases = [
      "https://www.instagram.com/reel/abc_123/": "https://www.instagram.com/reel/abc_123/",
      "https://www.youtube.com/watch?v=VIDEO_ID": "https://www.youtube.com/watch?v=VIDEO_ID",
      "https://x.com/OpenAI/status/1234567890": "https://x.com/OpenAI/status/1234567890",
      "https://www.pinterest.com/pin/1234567890/": "https://www.pinterest.com/pin/1234567890/",
      "https://www.reddit.com/r/flutter/comments/abc123/":
        "https://www.reddit.com/r/flutter/comments/abc123/",
      "https://www.linkedin.com/feed/update/urn:li:activity:1234567890123/":
        "https://www.linkedin.com/feed/update/urn:li:activity:1234567890123/",
      // A platform the app has never heard of still reaches the backend,
      // which is the whole point of dropping the allowlist.
      "https://some.new.platform.example/post/42": "https://some.new.platform.example/post/42",
      "http://insecure.example.com/post/1": "http://insecure.example.com/post/1",
    ]

    for (payload, expected) in cases {
      XCTAssertEqual(ShareUrlExtractor.extractSupportedUrl(from: payload), expected)
    }
  }

  func testPullsTheLinkOutOfSurroundingText() {
    XCTAssertEqual(
      ShareUrlExtractor.extractSupportedUrl(
        from: "Check this out https://www.youtube.com/shorts/VIDEO_ID?si=abc123"
      ),
      "https://www.youtube.com/shorts/VIDEO_ID?si=abc123"
    )
  }

  func testKeepsQueryParametersIntact() {
    let url = "https://m.youtube.com/watch?v=VIDEO_ID&feature=share&utm_source=x"

    XCTAssertEqual(ShareUrlExtractor.extractSupportedUrl(from: url), url)
  }

  func testTrimsTrailingSentencePunctuation() {
    XCTAssertEqual(
      ShareUrlExtractor.extractSupportedUrl(
        from: "Saved this https://www.instagram.com/reel/abc_123/."
      ),
      "https://www.instagram.com/reel/abc_123/"
    )
  }

  func testReturnsTheFirstLinkWhenAPayloadHasSeveral() {
    XCTAssertEqual(
      ShareUrlExtractor.extractSupportedUrl(
        from: "https://first.example/a and https://second.example/b"
      ),
      "https://first.example/a"
    )
  }

  func testRejectsThingsThatAreNotHttpLinks() {
    XCTAssertNil(ShareUrlExtractor.extractSupportedUrl(from: ""))
    XCTAssertNil(ShareUrlExtractor.extractSupportedUrl(from: "   "))
    XCTAssertNil(ShareUrlExtractor.extractSupportedUrl(from: "no link in here at all"))
    XCTAssertNil(ShareUrlExtractor.extractSupportedUrl(from: "ftp://example.com/file.txt"))
    XCTAssertNil(ShareUrlExtractor.extractSupportedUrl(from: "reelpin://open/reel/123"))
    XCTAssertNil(ShareUrlExtractor.extractSupportedUrl(from: "mailto:someone@example.com"))
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
