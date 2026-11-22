import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// A group khatma link (specs/014 research R16) or a widget tap (specs/017) the app was opened
  /// with.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for activity in connectionOptions.userActivities {
      DeviceChannel.shared.noteLink(activity.webpageURL, launch: true)
    }
    for context in connectionOptions.urlContexts {
      DeviceChannel.shared.noteLink(context.url, launch: true)
    }
  }

  /// A group khatma link opened while the app runs.
  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    DeviceChannel.shared.noteLink(userActivity.webpageURL, launch: false)
  }

  /// A widget tapped while the app runs.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      DeviceChannel.shared.noteLink(context.url, launch: false)
    }
  }
}
