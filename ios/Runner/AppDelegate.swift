import Flutter
import UIKit
import GoogleMaps
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
import receive_sharing_intent

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let shareHandoffChannelName = "com.chetanjain.reelpin/share_handoff"
  private let shareTokenKey = "share_token"
  private let baseUrlKey = "base_url"
  private let pushTokenKey = "push_token"
  private let pushPlatformKey = "push_platform"
  private let pendingSharesKey = "pending_urls"
  private let collectionsKey = "collections"
  private let collectionsDirKey = "collections_dir"
  private var shareHandoffChannel: FlutterMethodChannel?
  private let reelShareChannelName = "com.chetanjain.reelpin/reel_share"
  private var reelShareChannel: FlutterMethodChannel?
  private let deviceMetadataChannelName = "com.chetanjain.reelpin/device_metadata"
  private var deviceMetadataChannel: FlutterMethodChannel?

  override init() {
#if canImport(FirebaseCore)
    FirebaseApp.configure()
#endif
    super.init()
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Read API key from build settings (Secrets.xcconfig -> gitignored)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String,
       !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       !apiKey.contains("$(") {
      GMSServices.provideAPIKey(apiKey)
    }
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      configureShareHandoffChannel(binaryMessenger: controller.binaryMessenger)
      configureReelShareChannel(binaryMessenger: controller.binaryMessenger)
      configureDeviceMetadataChannel(binaryMessenger: controller.binaryMessenger)
    }
    return result
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let sharingIntent = SwiftReceiveSharingIntentPlugin.instance
    if sharingIntent.hasMatchingSchemePrefix(url: url) {
      return sharingIntent.application(app, open: url, options: options)
    }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
#if canImport(FirebaseMessaging)
    Messaging.messaging().apnsToken = deviceToken
#endif
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The share-handoff channel must bind to the engine that actually runs Dart.
    // Under the UIScene lifecycle, AppDelegate.window is nil at launch and the
    // SceneDelegate's rootViewController is unreliable at willConnect time, so the
    // earlier registrations can silently no-op (background shares never enqueue).
    // Register against the implicit engine's messenger here, the same path the
    // generated plugins use, so the channel is always reachable from Dart.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareHandoffChannel") {
      configureShareHandoffChannel(binaryMessenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReelShareChannel") {
      configureReelShareChannel(binaryMessenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeviceMetadataChannel") {
      configureDeviceMetadataChannel(binaryMessenger: registrar.messenger())
    }
  }

  func configureShareHandoffChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: shareHandoffChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "sync":
        guard let values = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Expected map", details: nil))
          return
        }
        self.syncShareHandoffValues(values)
        result(true)
      case "clear":
        self.clearShareHandoffValues()
        result(true)
      case "shareAssetsDir":
        // The Share Extension is a separate sandbox, so rendered artwork has to
        // live in the App Group container for it to be readable at all.
        result(self.shareAssetsDirectory())
      case "drainPending":
        result(self.drainPendingShares())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shareHandoffChannel = channel
  }

  func configureReelShareChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: reelShareChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "shareReelCard":
        guard
          let values = call.arguments as? [String: Any],
          let pngBytes = values["pngBytes"] as? FlutterStandardTypedData,
          let image = UIImage(data: pngBytes.data)
        else {
          result(FlutterError(code: "bad_args", message: "Missing share image", details: nil))
          return
        }

        let text = (values["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subject = (values["subject"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let items: [Any] = text.isEmpty ? [image] : [image, text]
        self.presentShareSheet(items: items, subject: subject, result: result)

      case "shareText":
        guard
          let values = call.arguments as? [String: Any],
          let text = (values["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty
        else {
          result(FlutterError(code: "bad_args", message: "Missing share text", details: nil))
          return
        }

        let subject = (values["subject"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.presentShareSheet(items: [text], subject: subject, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
    reelShareChannel = channel
  }

  /// Shared by shareReelCard and shareText: presents UIActivityViewController
  /// from the top-most controller, with the iPad popover anchored so it does
  /// not crash on a nil source view.
  private func presentShareSheet(
    items: [Any],
    subject: String,
    result: @escaping FlutterResult
  ) {
    let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if !subject.isEmpty {
      activity.setValue(subject, forKey: "subject")
    }
    guard let rootViewController = currentRootViewController() else {
      result(FlutterError(code: "no_presenter", message: "No view controller available", details: nil))
      return
    }
    let presenter = topViewController(from: rootViewController)
    if let popover = activity.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(activity, animated: true)
    result(true)
  }

  func configureDeviceMetadataChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: deviceMetadataChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "get" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result([
        "appVersion": Bundle.main.object(
          forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown",
        "appBuild": Bundle.main.object(
          forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "0",
        "timezone": TimeZone.current.identifier,
        "locale": Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
      ])
    }
    deviceMetadataChannel = channel
  }

  private func currentRootViewController() -> UIViewController? {
    let foregroundScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
    let foregroundWindow = foregroundScenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    return foregroundWindow?.rootViewController ?? window?.rootViewController
  }

  private func topViewController(from root: UIViewController) -> UIViewController {
    if let presented = root.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigation = root as? UINavigationController, let visible = navigation.visibleViewController {
      return topViewController(from: visible)
    }
    if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(from: selected)
    }
    return root
  }

  private func appGroupDefaults() -> UserDefaults? {
    guard let appGroupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String else {
      return nil
    }
    return UserDefaults(suiteName: appGroupId)
  }

  private func syncShareHandoffValues(_ values: [String: Any]) {
    guard let defaults = appGroupDefaults() else { return }
    set(defaults: defaults, key: shareTokenKey, value: values["shareToken"])
    set(defaults: defaults, key: baseUrlKey, value: values["baseUrl"])
    set(defaults: defaults, key: pushTokenKey, value: values["pushToken"])
    set(defaults: defaults, key: pushPlatformKey, value: values["pushPlatform"])
    set(defaults: defaults, key: collectionsKey, value: values["collections"])
    set(defaults: defaults, key: collectionsDirKey, value: values["collectionsDir"])
    defaults.synchronize()
  }

  private func clearShareHandoffValues() {
    guard let defaults = appGroupDefaults() else { return }
    defaults.removeObject(forKey: shareTokenKey)
    defaults.removeObject(forKey: baseUrlKey)
    defaults.removeObject(forKey: pushTokenKey)
    defaults.removeObject(forKey: pushPlatformKey)
    defaults.removeObject(forKey: collectionsKey)
    defaults.removeObject(forKey: collectionsDirKey)
    defaults.synchronize()
  }

  private func shareAssetsDirectory() -> String? {
    guard
      let appGroupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
      let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    else {
      return nil
    }
    let dir = container.appendingPathComponent("share_assets", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.path
  }

  private func drainPendingShares() -> String? {
    guard let defaults = appGroupDefaults() else { return nil }
    let pending = defaults.string(forKey: pendingSharesKey)
    defaults.removeObject(forKey: pendingSharesKey)
    defaults.synchronize()
    return pending
  }

  private func set(defaults: UserDefaults, key: String, value: Any?) {
    let cleaned = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let cleaned, !cleaned.isEmpty {
      defaults.set(cleaned, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }
}
