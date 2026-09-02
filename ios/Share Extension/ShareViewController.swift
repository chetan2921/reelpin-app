import UIKit

class ShareViewController: UIViewController {
  private let pendingSharesKey = "pending_urls"
  private let shareTokenKey = "share_token"
  private let baseUrlKey = "base_url"
  private let pushTokenKey = "push_token"
  private let pushPlatformKey = "push_platform"
  private let collectionsKey = "collections"
  private let collectionsDirKey = "collections_dir"
  private var hasStartedProcessing = false
  private var pendingSharedUrl: String?
  private var shareCollections: [ShareCollection] = []
  private var selectedCollectionIds: Set<String> = []
  private weak var primaryAction: UIButton?
  private var processingCard: ProcessingCardView?

  private lazy var collectionGrid: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.minimumInteritemSpacing = 12
    layout.minimumLineSpacing = 14
    layout.sectionInset = UIEdgeInsets(top: 4, left: 20, bottom: 4, right: 20)
    return UICollectionView(frame: .zero, collectionViewLayout: layout)
  }()
  private let statusContainer = UIView()
  private let statusIconContainer = UIView()
  private let statusIconView = UIImageView()
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private let statusLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    configureStatusView()
    // Read here rather than when the share resolves: iOS hands this extension a
    // near full-height sheet whatever we ask for, and the card has to be in it
    // from the first frame or the user still sees the empty panel.
    shareCollections = loadShareCollections()
    if shareCollections.isEmpty {
      configureProcessingCard()
    }
    showStatus("Saving to ReelPin", isLoading: true)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    processShareIfNeeded()
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    preferredContentSize = CGSize(width: view.bounds.width, height: 124)
    clearExtensionBackground()
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
        self.showStatusAndComplete(
          "Unsupported link.",
          isError: true
        )
        return
      }

      self.processingCard?.setPlatform(SharePlatformName.from(url: sharedUrl))

      let collections = self.shareCollections
      if collections.isEmpty {
        // No collections: keep the one-tap save this extension has always had.
        self.enqueueSharedUrl(sharedUrl, collectionIds: [])
      } else {
        self.pendingSharedUrl = sharedUrl
        self.presentCollectionPicker()
      }
    }
  }

  private func extractSharedUrl(completion: @escaping (String?) -> Void) {
    var parts: [String] = []

    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      completion(ShareUrlExtractor.extractSupportedUrl(from: parts.joined(separator: "\n")))
      return
    }

    for item in items {
      if let title = item.attributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines),
         !title.isEmpty {
        parts.append(title)
      }
      if let text = item.attributedContentText?.string
        .trimmingCharacters(in: .whitespacesAndNewlines),
        !text.isEmpty {
        parts.append(text)
      }
    }

    let providers = items.flatMap { $0.attachments ?? [] }
    if providers.isEmpty {
      completion(ShareUrlExtractor.extractSupportedUrl(from: parts.joined(separator: "\n")))
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
      completion(ShareUrlExtractor.extractSupportedUrl(from: parts.joined(separator: "\n")))
    }
  }

  private func enqueueSharedUrl(_ sharedUrl: String, collectionIds: [String]) {
    guard
      let defaults = appGroupDefaults(),
      let shareToken = cleanedString(defaults.string(forKey: shareTokenKey)),
      let baseUrl = cleanedString(defaults.string(forKey: baseUrlKey))
    else {
      savePendingShare(sharedUrl, collectionIds: collectionIds)
      showStatusAndComplete("Open ReelPin to sync.")
      return
    }

    postJson(
      baseUrl: baseUrl,
      path: "processing-jobs/reels",
      shareToken: shareToken,
      body: collectionIds.isEmpty
        ? ["url": sharedUrl]
        : ["url": sharedUrl, "collection_ids": collectionIds]
    ) { [weak self] result in
      guard let self else {
        return
      }

      switch result {
      case .success:
        self.registerStoredPushToken(defaults: defaults, baseUrl: baseUrl, shareToken: shareToken)
        self.showStatusAndComplete("Saved. Processing.")
      case .invalidShareToken:
        defaults.removeObject(forKey: self.shareTokenKey)
        defaults.synchronize()
        self.savePendingShare(sharedUrl, collectionIds: collectionIds)
        self.showStatusAndComplete("Open ReelPin and sign in again.", isError: true)
      case .failure:
        self.savePendingShare(sharedUrl, collectionIds: collectionIds)
        self.showStatusAndComplete("Open ReelPin to sync.")
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
    // [String: Any] rather than [String: String]: collection_ids is an array.
    body: [String: Any],
    completion: @escaping (ShareRequestResult) -> Void
  ) {
    guard let url = URL(string: apiUrl(baseUrl: baseUrl, path: path)) else {
      completion(.failure)
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 5
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.setValue(shareToken, forHTTPHeaderField: "X-Share-Token")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, response, _ in
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      let result = ShareResponseClassifier.classify(statusCode: statusCode, data: data)
      DispatchQueue.main.async {
        completion(result)
      }
    }.resume()
  }

  /// Stores the collections with the URL. Dropping them here filed the reel
  /// into the library only, with no sign anything was lost, whenever the
  /// extension could not post the share itself.
  private func savePendingShare(_ url: String, collectionIds: [String] = []) {
    guard let defaults = appGroupDefaults() else {
      return
    }

    let existing = defaults.string(forKey: pendingSharesKey) ?? "[]"
    let decoded = existing.data(using: .utf8).flatMap {
      try? JSONSerialization.jsonObject(with: $0)
    } as? [Any]
    var pending = decoded ?? []
    var entry: [String: Any] = ["url": url]
    if !collectionIds.isEmpty {
      entry["collection_ids"] = collectionIds
    }
    pending.append(entry)

    if let data = try? JSONSerialization.data(withJSONObject: pending),
       let value = String(data: data, encoding: .utf8) {
      defaults.set(value, forKey: pendingSharesKey)
      defaults.synchronize()
    }
  }

  private func showStatusAndComplete(_ message: String, isError: Bool = false) {
    showStatus(message, isError: isError)
    processingCard?.stopAnimating()
    // The share is already filed by this point; the rest is the user waiting to
    // be let go. An error is the one case worth reading, so it alone lingers.
    let hold: TimeInterval = isError ? 1.4 : 0.35
    DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
      UIView.animate(
        withDuration: 0.16,
        animations: {
          self.statusContainer.alpha = 0
          self.processingCard?.alpha = 0
        },
        completion: { _ in
          self.extensionContext?.completeRequest(returningItems: nil)
        }
      )
    }
  }

  // MARK: - Collection picker

  /// Reads the snapshot the app syncs into the App Group. Deliberately local:
  /// an extension has a tiny time budget and can be killed mid-request, so the
  /// picker must appear instantly rather than wait on the network.
  private func loadShareCollections() -> [ShareCollection] {
    guard
      let defaults = appGroupDefaults(),
      let raw = cleanedString(defaults.string(forKey: collectionsKey)),
      let data = raw.data(using: .utf8),
      let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return []
    }
    return parsed.compactMap { item in
      guard
        let id = (item["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
        !id.isEmpty
      else {
        return nil
      }
      let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let image = (item["image"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      return ShareCollection(
        id: id,
        name: name.isEmpty ? "Untitled" : name,
        image: (image?.isEmpty == false) ? image : nil
      )
    }
  }

  /// Artwork lives in the App Group container the app wrote it to.
  private func loadTileImage(named fileName: String?) -> UIImage? {
    guard
      let fileName,
      let defaults = appGroupDefaults(),
      let dir = cleanedString(defaults.string(forKey: collectionsDirKey))
    else {
      return nil
    }
    // The app writes a light and a dark render of every tile; fall back to the
    // light one when the dark file is not there yet.
    var candidates = [fileName]
    if traitCollection.userInterfaceStyle == .dark {
      let darkName = (fileName as NSString).deletingPathExtension + "_dark.png"
      candidates.insert(darkName, at: 0)
    }
    for candidate in candidates {
      let path = (dir as NSString).appendingPathComponent(candidate)
      if let image = UIImage(contentsOfFile: path) {
        return image
      }
    }
    return nil
  }

  /// AppColors.bg / .fg / .textSec, resolved against the device's mode. The
  /// sheet was pinned to a white surface, which is wrong in dark mode.
  private var bgColor: UIColor {
    traitCollection.userInterfaceStyle == .dark
      ? UIColor(white: 0.10, alpha: 1)
      : .white
  }

  private var fgColor: UIColor {
    traitCollection.userInterfaceStyle == .dark ? .white : .black
  }

  private var secondaryTextColor: UIColor {
    traitCollection.userInterfaceStyle == .dark
      ? UIColor(white: 0.80, alpha: 1)
      : UIColor(white: 0.27, alpha: 1)
  }

  private func presentCollectionPicker() {
    statusContainer.isHidden = true

    // Drag handle: 40x4 solid, matching AddToCollectionSheet in the app.
    let handle = UIView()
    handle.backgroundColor = fgColor
    handle.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(handle)

    let heading = UILabel()
    heading.text = "SAVE TO A COLLECTION"
    heading.font = Self.spaceMono(size: 17, bold: true)
    heading.textColor = fgColor
    heading.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(heading)

    let subtitle = UILabel()
    subtitle.text = "Tap the ones it belongs in. Skip to just save it."
    subtitle.font = Self.spaceMono(size: 12, bold: false)
    subtitle.textColor = secondaryTextColor
    subtitle.numberOfLines = 2
    subtitle.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(subtitle)

    view.backgroundColor = bgColor

    // A 2-up grid, matching the SAVED tab. The extension gets a full sheet on
    // iOS, so there is room to show the artwork rather than a bare list.
    collectionGrid.dataSource = self
    collectionGrid.delegate = self
    collectionGrid.backgroundColor = .clear
    collectionGrid.alwaysBounceVertical = true
    collectionGrid.translatesAutoresizingMaskIntoConstraints = false
    collectionGrid.register(CollectionFolderCell.self,
                            forCellWithReuseIdentifier: CollectionFolderCell.reuseId)
    view.addSubview(collectionGrid)

    // One button whose label states exactly what will happen. A "Save" /
    // "Just save" pair read as the same action twice.
    let action = actionButton(title: actionTitle(), filled: true)
    action.addTarget(self, action: #selector(saveWithSelectedCollections), for: .touchUpInside)
    action.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(action)
    primaryAction = action

    let bar = action

    NSLayoutConstraint.activate([
      handle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
      handle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      handle.widthAnchor.constraint(equalToConstant: 40),
      handle.heightAnchor.constraint(equalToConstant: 4),

      heading.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 18),
      heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      heading.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

      subtitle.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 4),
      subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      subtitle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

      collectionGrid.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
      collectionGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionGrid.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionGrid.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -12),

      bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
      // -18 rather than -14: the 4pt slab sits outside the button's bounds.
      bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
      bar.heightAnchor.constraint(equalToConstant: 48),
    ])

    preferredContentSize = CGSize(width: view.bounds.width, height: 520)
  }

  private func actionTitle() -> String {
    switch selectedCollectionIds.count {
    case 0: return "SAVE TO REELPIN"
    case 1: return "SAVE TO 1 COLLECTION"
    default: return "SAVE TO \(selectedCollectionIds.count) COLLECTIONS"
    }
  }

  /// Port of AppTheme.brutalBox: flat fill, 1pt black border, and a solid black
  /// slab offset down-right. shadowRadius 0 with full opacity is what turns
  /// CALayer's normally-soft shadow into the hard slab the app uses.
  private func actionButton(title: String, filled: Bool) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = Self.spaceMono(size: 14, bold: true)
    button.setTitleColor(filled ? .black : fgColor, for: .normal)
    button.backgroundColor = filled ? Self.accentYellow : bgColor
    button.layer.borderWidth = 1
    button.layer.borderColor = fgColor.cgColor
    button.layer.cornerRadius = 0
    button.layer.shadowColor = fgColor.cgColor
    button.layer.shadowOffset = CGSize(width: 4, height: 4)
    button.layer.shadowRadius = 0
    button.layer.shadowOpacity = 1
    button.layer.masksToBounds = false
    return button
  }

  /// The app's Space Mono, so native copy matches the rendered tiles. Falls
  /// back to the system monospace if the bundled face fails to load.
  private static func spaceMono(size: CGFloat, bold: Bool) -> UIFont {
    let name = bold ? "SpaceMono-Bold" : "SpaceMono-Regular"
    return UIFont(name: name, size: size)
      ?? .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
  }

  private static let accentYellow = UIColor(red: 1.0, green: 0xD6 / 255, blue: 0, alpha: 1)

  @objc private func saveWithSelectedCollections() {
    submitPendingShare(collectionIds: Array(selectedCollectionIds))
  }

  private func submitPendingShare(collectionIds: [String]) {
    guard let sharedUrl = pendingSharedUrl else {
      showStatusAndComplete("Unsupported link.", isError: true)
      return
    }
    collectionGrid.isHidden = true
    statusContainer.isHidden = false
    showStatus("Saving to ReelPin", isLoading: true)
    enqueueSharedUrl(sharedUrl, collectionIds: collectionIds)
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

  private func configureStatusView() {
    view.isOpaque = false
    view.backgroundColor = .clear

    statusContainer.translatesAutoresizingMaskIntoConstraints = false
    statusContainer.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.96)
    statusContainer.layer.cornerRadius = 16
    statusContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
    statusContainer.layer.borderWidth = 1
    statusContainer.layer.shadowColor = UIColor.black.cgColor
    statusContainer.layer.shadowOpacity = 0.22
    statusContainer.layer.shadowRadius = 14
    statusContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
    statusContainer.alpha = 0

    statusIconContainer.translatesAutoresizingMaskIntoConstraints = false
    statusIconContainer.layer.cornerRadius = 13
    statusIconContainer.clipsToBounds = true

    statusIconView.translatesAutoresizingMaskIntoConstraints = false
    statusIconView.contentMode = .scaleAspectFit
    statusIconView.tintColor = .black

    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    activityIndicator.color = .black
    activityIndicator.hidesWhenStopped = true

    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.textColor = .white
    statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
    statusLabel.numberOfLines = 1
    statusLabel.lineBreakMode = .byTruncatingTail

    view.addSubview(statusContainer)
    statusContainer.addSubview(statusIconContainer)
    statusIconContainer.addSubview(statusIconView)
    statusIconContainer.addSubview(activityIndicator)
    statusContainer.addSubview(statusLabel)

    let fillCardWidth = statusContainer.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48)
    fillCardWidth.priority = .defaultHigh

    NSLayoutConstraint.activate([
      statusContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      statusContainer.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -18
      ),
      fillCardWidth,
      statusContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
      statusContainer.heightAnchor.constraint(equalToConstant: 58),

      statusIconContainer.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 16),
      statusIconContainer.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
      statusIconContainer.widthAnchor.constraint(equalToConstant: 26),
      statusIconContainer.heightAnchor.constraint(equalToConstant: 26),

      statusIconView.centerXAnchor.constraint(equalTo: statusIconContainer.centerXAnchor),
      statusIconView.centerYAnchor.constraint(equalTo: statusIconContainer.centerYAnchor),
      statusIconView.widthAnchor.constraint(equalToConstant: 14),
      statusIconView.heightAnchor.constraint(equalToConstant: 14),

      activityIndicator.centerXAnchor.constraint(equalTo: statusIconContainer.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: statusIconContainer.centerYAnchor),

      statusLabel.leadingAnchor.constraint(equalTo: statusIconContainer.trailingAnchor, constant: 12),
      statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -16),
      statusLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
    ])

    clearExtensionBackground()
  }

  /// Fills the sheet iOS insists on presenting. Only reached when the user has
  /// no collections — the picker takes the whole view otherwise — and laid out
  /// above the status pill that already sits at the bottom.
  private func configureProcessingCard() {
    let card = ProcessingCardView(
      fgColor: fgColor,
      bgColor: bgColor,
      accent: Self.accentYellow,
      font: { Self.spaceMono(size: $0, bold: $1) }
    )
    card.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(card)
    processingCard = card

    // The one thing worth saying to a user who has no collections, in the space
    // that would otherwise stay empty.
    let nudge = UILabel()
    nudge.text = "MAKE A COLLECTION IN REELPIN AND YOU CAN FILE SHARES RIGHT HERE."
    nudge.font = Self.spaceMono(size: 11, bold: false)
    nudge.textColor = secondaryTextColor
    nudge.numberOfLines = 2
    nudge.textAlignment = .center
    nudge.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(nudge)

    let width = card.widthAnchor.constraint(
      equalTo: view.widthAnchor,
      multiplier: 0.5
    )
    width.priority = .defaultHigh

    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -28),
      width,
      card.widthAnchor.constraint(lessThanOrEqualToConstant: 210),
      // The grid's compact aspect, so this is the card the app will show.
      card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 1 / 0.74),

      nudge.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 22),
      nudge.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
      nudge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
      nudge.bottomAnchor.constraint(
        lessThanOrEqualTo: statusContainer.topAnchor,
        constant: -16
      ),
    ])

    card.startAnimating()
  }

  private func showStatus(
    _ message: String,
    isLoading: Bool = false,
    isError: Bool = false
  ) {
    statusLabel.text = message
    if isLoading {
      statusIconContainer.backgroundColor = UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1.00)
      statusIconView.isHidden = true
      activityIndicator.startAnimating()
    } else {
      activityIndicator.stopAnimating()
      statusIconView.isHidden = false
      statusIconContainer.backgroundColor = isError
        ? UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1.00)
        : UIColor(red: 0.78, green: 1.00, blue: 0.22, alpha: 1.00)
      statusIconView.tintColor = isError ? .white : .black
      statusIconView.image = UIImage(systemName: isError ? "xmark" : "checkmark")
    }

    UIView.animate(withDuration: 0.18) {
      self.statusContainer.alpha = 1
    }
  }

  private func clearExtensionBackground() {
    view.isOpaque = false
    view.backgroundColor = .clear
    view.superview?.isOpaque = false
    view.superview?.backgroundColor = .clear
  }
}

struct ShareCollection {
  let id: String
  let name: String
  let image: String?
}

extension ShareViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    shareCollections.count
  }

  func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: CollectionFolderCell.reuseId, for: indexPath
    ) as! CollectionFolderCell
    let collection = shareCollections[indexPath.item]
    cell.configure(
      name: collection.name,
      image: loadTileImage(named: collection.image),
      isChecked: selectedCollectionIds.contains(collection.id)
    )
    return cell
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    let columns: CGFloat = 2
    let insets: CGFloat = 40
    let gap: CGFloat = 12
    let width = (collectionView.bounds.width - insets - gap * (columns - 1)) / columns
    return CGSize(width: floor(width), height: floor(width * 0.92))
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let collection = shareCollections[indexPath.item]
    if selectedCollectionIds.contains(collection.id) {
      selectedCollectionIds.remove(collection.id)
    } else {
      selectedCollectionIds.insert(collection.id)
    }
    collectionView.reloadItems(at: [indexPath])
    primaryAction?.setTitle(actionTitle(), for: .normal)
  }
}

/// The waiting card the share sheet shows when the user has no collections to
/// pick from.
///
/// Same shape as the placeholder the app puts in its own grid — brutalist
/// border, hard shadow, yellow water climbing a rectangle — so the sheet
/// previews the card the user is about to find on Home rather than an empty
/// panel. The rise is indeterminate on purpose: nothing is being processed yet,
/// only sent, and the sheet closes the moment the send returns.
final class ProcessingCardView: UIView {
  private let card = UIView()
  private let water = CAShapeLayer()
  private let titleLabel = UILabel()
  private let platformLabel = UILabel()

  private var displayLink: CADisplayLink?
  private var elapsed: CFTimeInterval = 0
  private var lastTick: CFTimeInterval = 0

  /// Matches the app card: never fill to the brim, or a card that keeps
  /// sitting there reads as finished-but-stuck.
  private let maxLevel: CGFloat = 0.85
  private let minLevel: CGFloat = 0.06
  /// How long the water takes to climb from empty to `maxLevel`. Chosen to
  /// outlast a typical enqueue, so the card is still rising when it is
  /// dismissed rather than parked at the top waiting.
  private let riseDuration: CFTimeInterval = 3.2

  init(fgColor: UIColor, bgColor: UIColor, accent: UIColor, font: (CGFloat, Bool) -> UIFont) {
    super.init(frame: .zero)

    card.backgroundColor = bgColor
    card.layer.borderColor = fgColor.cgColor
    card.layer.borderWidth = 3
    card.layer.shadowColor = fgColor.cgColor
    card.layer.shadowOffset = CGSize(width: 4, height: 4)
    card.layer.shadowRadius = 0
    card.layer.shadowOpacity = 1
    card.layer.masksToBounds = false
    card.translatesAutoresizingMaskIntoConstraints = false
    addSubview(card)

    // Its own clipped host, so the water is cut by the card's edges while the
    // card itself keeps its unclipped drop shadow.
    let well = UIView()
    well.backgroundColor = .clear
    well.clipsToBounds = true
    well.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(well)
    water.fillColor = accent.cgColor
    well.layer.addSublayer(water)

    titleLabel.text = "SAVING"
    titleLabel.font = font(15, true)
    titleLabel.textColor = fgColor
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(titleLabel)

    platformLabel.text = "TO REELPIN"
    platformLabel.font = font(11, true)
    platformLabel.textColor = fgColor.withAlphaComponent(0.65)
    platformLabel.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(platformLabel)

    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: topAnchor),
      card.leadingAnchor.constraint(equalTo: leadingAnchor),
      card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

      well.topAnchor.constraint(equalTo: card.topAnchor),
      well.leadingAnchor.constraint(equalTo: card.leadingAnchor),
      well.trailingAnchor.constraint(equalTo: card.trailingAnchor),
      well.bottomAnchor.constraint(equalTo: card.bottomAnchor),

      platformLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
      platformLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
      platformLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

      titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
      titleLabel.bottomAnchor.constraint(equalTo: platformLabel.topAnchor, constant: -2),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Named once the shared link has been read, so the card says what it is
  /// holding rather than staying generic.
  func setPlatform(_ name: String?) {
    platformLabel.text = name?.uppercased() ?? "TO REELPIN"
  }

  func startAnimating() {
    guard displayLink == nil else { return }
    lastTick = CACurrentMediaTime()
    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  func stopAnimating() {
    displayLink?.invalidate()
    displayLink = nil
  }

  deinit {
    displayLink?.invalidate()
  }

  @objc private func tick() {
    let now = CACurrentMediaTime()
    elapsed += now - lastTick
    lastTick = now
    redrawWater()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    redrawWater()
  }

  private func redrawWater() {
    let size = card.bounds.size
    guard size.width > 0, size.height > 0 else { return }

    // Ease out, so the climb is quick at first and slows as it approaches the
    // cap rather than stopping dead.
    let t = min(elapsed / riseDuration, 1)
    let eased = 1 - pow(1 - t, 3)
    let level = minLevel + (maxLevel - minLevel) * CGFloat(eased)

    let amplitude = size.height * 0.022
    let baseline = size.height * (1 - level) + amplitude
    let sweep = CGFloat(elapsed.truncatingRemainder(dividingBy: 2.6) / 2.6) * 2 * .pi

    // Two sine waves of different length and speed, summed: one alone reads as
    // a sliding ruler. Same shape the app's card paints.
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 0, y: size.height))
    path.addLine(to: CGPoint(x: 0, y: baseline))
    var x: CGFloat = 0
    while x <= size.width {
      let ratio = x / size.width
      let y = baseline
        + sin(ratio * 2 * .pi + sweep) * amplitude
        + sin(ratio * 5 * .pi - sweep * 1.7) * amplitude * 0.45
      path.addLine(to: CGPoint(x: x, y: y))
      x += 2
    }
    path.addLine(to: CGPoint(x: size.width, y: size.height))
    path.close()

    // The path is rebuilt every frame, so the layer's implicit animation would
    // fight it.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    water.frame = CGRect(origin: .zero, size: size)
    water.path = path.cgPath
    CATransaction.commit()
  }
}

/// Names the platform a shared link belongs to, mirroring the hosts the backend
/// recognises. Only used for the card's label — what is actually supported
/// stays the backend's decision.
enum SharePlatformName {
  static func from(url: String) -> String? {
    guard
      let host = URLComponents(string: url)?.host?.lowercased()
    else {
      return nil
    }
    let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

    switch true {
    case bare.hasSuffix("instagram.com"), bare == "instagr.am":
      return "Instagram"
    case bare.hasSuffix("tiktok.com"):
      return "TikTok"
    case bare.hasSuffix("youtube.com"), bare == "youtu.be":
      return "YouTube"
    case bare == "x.com", bare == "twitter.com", bare == "t.co":
      return "X"
    case bare.hasSuffix("linkedin.com"):
      return "LinkedIn"
    case bare.hasSuffix("reddit.com"), bare == "redd.it":
      return "Reddit"
    case bare.hasSuffix("pinterest.com"), bare == "pin.it":
      return "Pinterest"
    default:
      return nil
    }
  }
}
