import SwiftUI
import WidgetKit

/// Mathani's iPhone widgets (specs/017): they read the snapshot the app writes to the App Group
/// and never use the network (FR-002).
@main
struct MathaniWidgetsBundle: WidgetBundle {
  var body: some Widget {
    PrayerWidget()
    QuranWidget()
    KhatmaWidget()
  }
}
