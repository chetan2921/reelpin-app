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
  private var shareHandoffChannel: FlutterMethodChannel?

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
    // Read API key from build settings (Secrets.xcconfig → gitignored)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String {
      GMSServices.provideAPIKey(apiKey)
    }
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      configureShareHandoffChannel(binaryMessenger: controller.binaryMessenger)
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
      case "drainPending":
        result(self.drainPendingShares())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    shareHandoffChannel = channel
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
    defaults.synchronize()
  }

  private func clearShareHandoffValues() {
    guard let defaults = appGroupDefaults() else { return }
    defaults.removeObject(forKey: shareTokenKey)
    defaults.removeObject(forKey: baseUrlKey)
    defaults.removeObject(forKey: pushTokenKey)
    defaults.removeObject(forKey: pushPlatformKey)
    defaults.synchronize()
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
