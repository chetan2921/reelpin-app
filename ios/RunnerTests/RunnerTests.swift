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
}
