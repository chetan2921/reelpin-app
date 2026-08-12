import UIKit

class ShareViewController: UIViewController {
  private let pendingSharesKey = "pending_urls"
  private let shareTokenKey = "share_token"
  private let baseUrlKey = "base_url"
  private let pushTokenKey = "push_token"
  private let pushPlatformKey = "push_platform"
  private let collectionsKey = "collections"
  private var hasStartedProcessing = false
  private var pendingSharedUrl: String?
  private var shareCollections: [ShareCollection] = []
  private var selectedCollectionIds: Set<String> = []
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

      let collections = self.loadShareCollections()
      if collections.isEmpty {
        // No collections: keep the one-tap save this extension has always had.
        self.enqueueSharedUrl(sharedUrl, collectionIds: [])
      } else {
        self.pendingSharedUrl = sharedUrl
        self.shareCollections = collections
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
      savePendingShare(sharedUrl)
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
        self.savePendingShare(sharedUrl)
        self.showStatusAndComplete("Open ReelPin and sign in again.", isError: true)
      case .failure:
        self.savePendingShare(sharedUrl)
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

  private func showStatusAndComplete(_ message: String, isError: Bool = false) {
    showStatus(message, isError: isError)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      UIView.animate(
        withDuration: 0.16,
        animations: {
          self.statusContainer.alpha = 0
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
      return ShareCollection(id: id, name: name.isEmpty ? "Untitled" : name)
    }
  }

  private func presentCollectionPicker() {
    statusContainer.isHidden = true

    let heading = UILabel()
    heading.text = "Save to a collection"
    heading.font = .monospacedSystemFont(ofSize: 17, weight: .bold)
    heading.textColor = .label
    heading.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(heading)

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

    let bar = UIStackView()
    bar.axis = .horizontal
    bar.distribution = .fillEqually
    bar.spacing = 12
    bar.translatesAutoresizingMaskIntoConstraints = false

    // "Just save" stays a first-class choice: sharing without a collection is
    // the fast path and must not read as cancelling.
    let skip = actionButton(title: "Just save", filled: false)
    skip.addTarget(self, action: #selector(saveWithoutCollections), for: .touchUpInside)
    let save = actionButton(title: "Save", filled: true)
    save.addTarget(self, action: #selector(saveWithSelectedCollections), for: .touchUpInside)
    bar.addArrangedSubview(skip)
    bar.addArrangedSubview(save)
    view.addSubview(bar)

    NSLayoutConstraint.activate([
      heading.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      heading.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      collectionGrid.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 12),
      collectionGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionGrid.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionGrid.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -12),

      bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
      bar.heightAnchor.constraint(equalToConstant: 48),
    ])

    preferredContentSize = CGSize(width: view.bounds.width, height: 520)
  }

  private func actionButton(title: String, filled: Bool) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = .monospacedSystemFont(ofSize: 14, weight: .bold)
    button.setTitleColor(.black, for: .normal)
    button.backgroundColor = filled
      ? UIColor(red: 1.0, green: 0xD6 / 255, blue: 0.0, alpha: 1)
      : .white
    button.layer.borderWidth = 2
    button.layer.borderColor = UIColor.black.cgColor
    return button
  }

  @objc private func saveWithoutCollections() {
    submitPendingShare(collectionIds: [])
  }

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
      index: indexPath.item,
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
  }
}
