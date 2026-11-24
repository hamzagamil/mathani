import Foundation
import WatchConnectivity
import WidgetKit

/// Receives the watch copy from the iPhone (specs/017 contracts/watch-sync.md), keeps the newest
/// in the watch's App Group, and reloads the watch widgets. It never computes times (FR-018).
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
  static let shared = WatchStore()

  @Published private(set) var snapshot: WidgetSnapshot?

  override init() {
    super.init()
    snapshot = WidgetSnapshot.load(suite: WidgetSnapshot.watchSuite)
    #if DEBUG
      // Store screenshots on a simulator with no paired iPhone (.github/workflows/watch-screenshots.yml):
      // `-demoSnapshotPath <file>` shows a watch copy from a file, without keeping it.
      let args = ProcessInfo.processInfo.arguments
      if let i = args.firstIndex(of: "-demoSnapshotPath"), i + 1 < args.count,
        let text = try? String(contentsOfFile: args[i + 1], encoding: .utf8)
      {
        snapshot = WidgetSnapshot.decode(text)
      }
    #endif
  }

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    if session.delegate == nil { session.delegate = self }
    if session.activationState != .activated { session.activate() }
  }

  /// Keeps `text` if it is newer than the stored copy.
  func receive(_ text: String?) {
    guard let text, let incoming = WidgetSnapshot.decode(text) else { return }
    DispatchQueue.main.async {
      if let current = self.snapshot, current.madeAtUtc >= incoming.madeAtUtc { return }
      UserDefaults(suiteName: WidgetSnapshot.watchSuite)?.set(text, forKey: WidgetSnapshot.key)
      self.snapshot = incoming
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
    receive(session.receivedApplicationContext["watch"] as? String)
  }

  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    receive(context["watch"] as? String)
  }

  /// The prompt complication update (`transferCurrentComplicationUserInfo`).
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    receive(userInfo["watch"] as? String)
  }
}
