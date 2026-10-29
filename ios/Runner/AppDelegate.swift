import AudioToolbox
import Flutter
import Network
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DeviceChannel.shared.start()
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MathaniDeviceChannel") {
      DeviceChannel.shared.register(messenger: registrar.messenger())
    }
  }
}

/// Network type, free storage and backup exclusion for recitation downloads
/// (specs/004-ayah-recitations, research R8); device support, the Settings link and the mistake
/// tone for memorization (specs/006, research R12, R15).
final class DeviceChannel {
  static let shared = DeviceChannel()

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "app.mathani.device.network")
  private let lock = NSLock()
  private var path: NWPath?
  private var channel: FlutterMethodChannel?
  private var mistakeSound: SystemSoundID = 0

  func start() {
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      self.lock.lock()
      self.path = path
      self.lock.unlock()
    }
    monitor.start(queue: queue)
  }

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.mathani/device", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterMethodNotImplemented) }
      switch call.method {
      case "networkState":
        result(self.networkState())
      case "freeBytes":
        result(self.freeBytes())
      case "excludeFromBackup":
        let args = call.arguments as? [String: Any]
        if let path = args?["path"] as? String { self.excludeFromBackup(path) }
        result(nil)
      case "deviceSupport":
        result(["arm64": true, "ramBytes": Int64(ProcessInfo.processInfo.physicalMemory)])
      case "openAppSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      case "playMistakeTone":
        self.playMistakeTone()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func networkState() -> String {
    lock.lock()
    let current = path ?? monitor.currentPath
    lock.unlock()
    guard current.status == .satisfied else { return "none" }
    return current.isExpensive || current.isConstrained ? "metered" : "unmetered"
  }

  private func freeBytes() -> Int64 {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values?.volumeAvailableCapacityForImportantUsage ?? 0
  }

  /// A system sound, so the silent switch mutes it (research R12).
  private func playMistakeTone() {
    if mistakeSound == 0,
      let url = Bundle.main.url(forResource: "mistake", withExtension: "caf")
    {
      AudioServicesCreateSystemSoundID(url as CFURL, &mistakeSound)
    }
    if mistakeSound != 0 { AudioServicesPlaySystemSound(mistakeSound) }
  }

  private func excludeFromBackup(_ path: String) {
    var url = URL(fileURLWithPath: path, isDirectory: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
  }
}
