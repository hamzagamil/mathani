import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// A group khatma link the app was opened with (specs/014 research R16).
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for activity in connectionOptions.userActivities {
      DeviceChannel.shared.noteLink(activity.webpageURL, launch: true)
    }
  }

  /// A group khatma link opened while the app runs.
  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    DeviceChannel.shared.noteLink(userActivity.webpageURL, launch: false)
  }
}
