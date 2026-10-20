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

  func testClassifiesSubmissionsAndReelsAsSaved() {
    XCTAssertEqual(
      ShareResponseClassifier.classify(statusCode: 202, data: Self.submissionAccepted),
      .success
    )
    XCTAssertEqual(
      ShareResponseClassifier.classify(statusCode: 202, data: Self.submissionInFlight),
      .success
    )
    XCTAssertEqual(
      ShareResponseClassifier.classify(
        statusCode: 200,
        data: #"{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","already_saved":true}"#.data(using: .utf8)
      ),
      .success
    )
  }

  func testClassifiesExpiredAndMissingShareTokens() {
    XCTAssertEqual(
      ShareResponseClassifier.classify(statusCode: 401, data: Self.errorBody("invalid_share_token")),
      .invalidShareToken
    )
    XCTAssertEqual(
      ShareResponseClassifier.classify(statusCode: 401, data: Self.errorBody("share_token_required")),
      .invalidShareToken
    )
    XCTAssertEqual(
      ShareResponseClassifier.classify(statusCode: 401, data: Self.errorBody("unauthorized")),
      .failure
    )
  }

  func testClassifiesEveryOtherErrorAsFailure() {
    let cases: [(Int, String)] = [
      (422, "validation_error"),
      (429, "rate_limited"),
      (429, "active_job_limit"),
      (409, "idempotency_conflict"),
      (503, "processing_unavailable"),
      (503, "spend_limit_reached"),
    ]
    for (statusCode, code) in cases {
      XCTAssertEqual(
        ShareResponseClassifier.classify(statusCode: statusCode, data: Self.errorBody(code)),
        .failure
      )
    }
    XCTAssertEqual(ShareResponseClassifier.classify(statusCode: 0, data: nil), .failure)
  }

  // Response bodies from reelpin-go api/fixtures (submission_accepted.json,
  // submission_in_flight.json, error_*.json).
  private static let submissionAccepted = #"{"already_saved":false,"collection_ids":[],"created_at":"2026-09-06T10:00:00Z","current_step":"queued","failure_code":null,"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","progress_percent":0,"result_reel_id":null,"source_platform":null,"status":"queued","status_message":"Queued for processing.","updated_at":"2026-09-06T10:00:00Z","url":"https://www.instagram.com/reel/C8abc123/"}"#.data(using: .utf8)
  private static let submissionInFlight = #"{"already_saved":true,"collection_ids":[],"created_at":"2026-09-06T10:00:00Z","current_step":"download","failure_code":null,"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","progress_percent":40,"result_reel_id":null,"source_platform":null,"status":"processing","status_message":"Processing is in progress.","updated_at":"2026-09-06T10:01:00Z","url":"https://www.instagram.com/reel/C8abc123/"}"#.data(using: .utf8)

  private static func errorBody(_ code: String) -> Data? {
    #"{"error":{"code":"\#(code)","message":"m","request_id":"fixture-request-id","retryable":false}}"#
      .data(using: .utf8)
  }
}
