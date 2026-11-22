import CryptoKit
import Flutter
import Foundation
import WatchConnectivity
import WidgetKit

/// The `app.mathani/widgets` channel on iPhone (specs/017 contracts/widget-snapshot.md): keeps the
/// snapshot in the App Group for the widgets, reloads them only on a real change, and sends the
/// watch copy to a paired Apple Watch (contracts/watch-sync.md).
final class WidgetBridge: NSObject, WCSessionDelegate {
  static let shared = WidgetBridge()

  private static let suite = "group.com.mthani.app"
  private static let snapshotKey = "widgetSnapshot"
  private static let hashKey = "widgetSnapshotHash"
  private var channel: FlutterMethodChannel?
  /// The watch copy waiting for the session to activate, and the last one sent.
  private var pendingWatch: String?
  private var sentWatch: String?

  func start() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.mathani/widgets", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterMethodNotImplemented) }
      switch call.method {
      case "update":
        let args = call.arguments as? [String: Any]
        guard let snapshot = args?["snapshot"] as? String else {
          return result(FlutterError(code: "invalid", message: "No snapshot", details: nil))
        }
        self.store(snapshot)
        if let watch = args?["watch"] as? String { self.sendToWatch(watch) }
        result(nil)
      case "placed":
        WidgetCenter.shared.getCurrentConfigurations { info in
          let kinds = Set((try? info.get())?.map(\.kind) ?? [])
          DispatchQueue.main.async {
            result(["prayer", "quran", "khatma"].filter { kinds.contains($0) })
          }
        }
      case "clear":
        let defaults = UserDefaults(suiteName: Self.suite)
        defaults?.removeObject(forKey: Self.snapshotKey)
        defaults?.removeObject(forKey: Self.hashKey)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// Writes the snapshot; reloads the widgets only if it changed, within iOS's reload budget.
  private func store(_ snapshot: String) {
    guard let defaults = UserDefaults(suiteName: Self.suite) else { return }
    let hash = SHA256.hash(data: Data(snapshot.utf8)).map { String(format: "%02x", $0) }.joined()
    if defaults.string(forKey: Self.hashKey) == hash { return }
    defaults.set(snapshot, forKey: Self.snapshotKey)
    defaults.set(hash, forKey: Self.hashKey)
    WidgetCenter.shared.reloadAllTimelines()
  }

  private func sendToWatch(_ watch: String) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else {
      pendingWatch = watch
      return
    }
    pendingWatch = nil
    guard session.isPaired, session.isWatchAppInstalled, watch != sentWatch else { return }
    do {
      try session.updateApplicationContext(["watch": watch])
      sentWatch = watch
    } catch {
      return
    }
    // A prompt complication update when one is on the watch face (research R5).
    if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
      session.transferCurrentComplicationUserInfo(["watch": watch])
    }
  }

  func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
    DispatchQueue.main.async {
      if let watch = self.pendingWatch { self.sendToWatch(watch) }
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  /// After switching to another watch: activate again for the new one.
  func sessionDidDeactivate(_ session: WCSession) {
    sentWatch = nil
    session.activate()
  }
}
