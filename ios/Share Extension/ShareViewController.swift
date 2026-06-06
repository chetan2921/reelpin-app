import receive_sharing_intent
import UIKit

class ShareViewController: RSIShareViewController {
  private let supportedUrlPattern =
    #"https?://(www\.)?(instagram\.com/(reel|p|tv)/[A-Za-z0-9_-]+|((vt|vm)\.)?tiktok\.com/[A-Za-z0-9@._/\-]+|youtube\.com/shorts/[A-Za-z0-9_-]+|youtu\.be/[A-Za-z0-9_-]+)(/?\S*)?"#
  private let pendingSharesKey = "pending_urls"
  private let shareTokenKey = "share_token"
  private let baseUrlKey = "base_url"
  private let pushTokenKey = "push_token"
  private let pushPlatformKey = "push_platform"
  private var hasStartedProcessing = false

  override func shouldAutoRedirect() -> Bool {
    false
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    processShareIfNeeded()
  }

  override func didSelectPost() {
    processShareIfNeeded()
  }

  override func presentationAnimationDidFinish() {
    super.presentationAnimationDidFinish()
    navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Save"
  }

  private func processShareIfNeeded() {
    if hasStartedProcessing {
      return
    }
    hasStartedProcessing = true

    extractSharedUrl { [weak self] sharedUrl in
      guard let self else {
        return
      }

      guard let sharedUrl else {
        self.showStatusAndComplete("ReelPin could not find a supported reel link.")
        return
      }

      self.enqueueSharedUrl(sharedUrl)
    }
  }

  private func extractSharedUrl(completion: @escaping (String?) -> Void) {
    var parts: [String] = []
    if let text = contentText?.trimmingCharacters(in: .whitespacesAndNewlines),
       !text.isEmpty {
      parts.append(text)
    }

    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      completion(extractSupportedUrl(from: parts.joined(separator: "\n")))
      return
    }

    let providers = items.flatMap { $0.attachments ?? [] }
    if providers.isEmpty {
      completion(extractSupportedUrl(from: parts.joined(separator: "\n")))
      return
    }

    let group = DispatchGroup()
    let supportedTypes = [
      "public.url",
      "public.plain-text",
      "public.text",
      "public.utf8-plain-text",
    ]

    for provider in providers {
      guard let typeIdentifier = supportedTypes.first(
        where: { provider.hasItemConformingToTypeIdentifier($0) }
      ) else {
        continue
      }

      group.enter()
      provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) {
        item,
        _ in
        DispatchQueue.main.async {
          if let url = item as? URL {
            parts.append(url.absoluteString)
          } else if let text = item as? String {
            parts.append(text)
          } else if let data = item as? Data,
                    let text = String(data: data, encoding: .utf8) {
            parts.append(text)
          }
          group.leave()
        }
      }
    }

    group.notify(queue: .main) {
      completion(self.extractSupportedUrl(from: parts.joined(separator: "\n")))
    }
  }

  private func extractSupportedUrl(from text: String) -> String? {
    guard
      let regex = try? NSRegularExpression(
        pattern: supportedUrlPattern,
        options: [.caseInsensitive]
      )
    else {
      return nil
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard
      let match = regex.firstMatch(in: text, options: [], range: range),
      let matchRange = Range(match.range, in: text)
    else {
      return nil
    }

    return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func enqueueSharedUrl(_ sharedUrl: String) {
    guard
      let defaults = appGroupDefaults(),
      let shareToken = cleanedString(defaults.string(forKey: shareTokenKey)),
      let baseUrl = cleanedString(defaults.string(forKey: baseUrlKey))
    else {
      savePendingShare(sharedUrl)
      showStatusAndComplete("Saved to ReelPin. Open the app to finish.")
      return
    }

    postJson(
      baseUrl: baseUrl,
      path: "processing-jobs/reels",
      shareToken: shareToken,
      body: ["url": sharedUrl]
    ) { [weak self] success in
      guard let self else {
        return
      }

      if success {
        self.registerStoredPushToken(defaults: defaults, baseUrl: baseUrl, shareToken: shareToken)
        self.showStatusAndComplete("Saved to ReelPin. Processing in background.")
      } else {
        self.savePendingShare(sharedUrl)
        self.showStatusAndComplete("Saved to ReelPin. Open the app to finish.")
      }
    }
  }

  private func registerStoredPushToken(
    defaults: UserDefaults,
    baseUrl: String,
    shareToken: String
  ) {
    guard let token = cleanedString(defaults.string(forKey: pushTokenKey)) else {
      return
    }
    let platform = cleanedString(defaults.string(forKey: pushPlatformKey)) ?? "ios"
    postJson(
      baseUrl: baseUrl,
      path: "device-push-tokens",
      shareToken: shareToken,
      body: ["token": token, "platform": platform]
    ) { _ in }
  }

  private func postJson(
    baseUrl: String,
    path: String,
    shareToken: String,
    body: [String: String],
    completion: @escaping (Bool) -> Void
  ) {
    guard let url = URL(string: apiUrl(baseUrl: baseUrl, path: path)) else {
      completion(false)
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.setValue(shareToken, forHTTPHeaderField: "X-Share-Token")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { _, response, _ in
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      DispatchQueue.main.async {
        completion((200...299).contains(statusCode))
      }
    }.resume()
  }

  private func savePendingShare(_ url: String) {
    guard let defaults = appGroupDefaults() else {
      return
    }

    let existing = defaults.string(forKey: pendingSharesKey) ?? "[]"
    let decoded = existing.data(using: .utf8).flatMap {
      try? JSONSerialization.jsonObject(with: $0)
    } as? [Any]
    var pending = decoded ?? []
    pending.append(url)

    if let data = try? JSONSerialization.data(withJSONObject: pending),
       let value = String(data: data, encoding: .utf8) {
      defaults.set(value, forKey: pendingSharesKey)
      defaults.synchronize()
    }
  }

  private func showStatusAndComplete(_ message: String) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    present(alert, animated: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
      alert.dismiss(animated: true) {
        self.extensionContext?.completeRequest(returningItems: nil)
      }
    }
  }

  private func appGroupDefaults() -> UserDefaults? {
    guard let appGroupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String else {
      return nil
    }
    return UserDefaults(suiteName: appGroupId)
  }

  private func cleanedString(_ value: String?) -> String? {
    let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned?.isEmpty == false ? cleaned : nil
  }

  private func apiUrl(baseUrl: String, path: String) -> String {
    let cleanBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let prefix = cleanBase.hasSuffix("/api/v1") ? "" : "/api/v1"
    return "\(cleanBase)\(prefix)/\(cleanPath)"
  }
}
