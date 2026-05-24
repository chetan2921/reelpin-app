import Flutter
import UIKit
import receive_sharing_intent

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let url = connectionOptions.urlContexts.first?.url {
      let sharingIntent = SwiftReceiveSharingIntentPlugin.instance
      if sharingIntent.hasMatchingSchemePrefix(url: url) {
        _ = sharingIntent.application(
          UIApplication.shared,
          didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: url]
        )
      }
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let sharingIntent = SwiftReceiveSharingIntentPlugin.instance
    for context in URLContexts where sharingIntent.hasMatchingSchemePrefix(url: context.url) {
      _ = sharingIntent.application(UIApplication.shared, open: context.url, options: [:])
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
