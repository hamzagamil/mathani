package app.mathani.mathani.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle

/** The prayer widget (specs/017 User Story 1). */
class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        WidgetRefresher.refreshAll(context)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        manager.updateAppWidget(id, WidgetViews.prayer(context, SnapshotStore(context).snapshot(), options, System.currentTimeMillis()))
    }

    override fun onDisabled(context: Context) = WidgetRefresher.refreshAll(context)
}

/** The Quran widget (specs/017 User Story 2). */
class QuranWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        WidgetRefresher.refreshAll(context)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        manager.updateAppWidget(id, WidgetViews.quran(context, SnapshotStore(context).snapshot(), options))
    }
}

/** Redraws at each prayer time and after clock, zone, language or boot changes (research R3). */
class WidgetTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = WidgetRefresher.refreshAll(context)
}

object WidgetRefresher {
    private const val TICK_ACTION = "app.mathani.WIDGET_TICK"
    // Distinct from the prayer alerts' request codes, which are 31-bit alert ids.
    private const val TICK_REQUEST = -17

    fun ids(context: Context, provider: Class<*>): IntArray =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, provider))

    /** Redraws every Mathani widget from the stored snapshot, then sets the next redraw. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val snapshot = SnapshotStore(context).snapshot()
        val now = System.currentTimeMillis()
        for (id in ids(context, PrayerWidgetProvider::class.java)) {
            manager.updateAppWidget(id, WidgetViews.prayer(context, snapshot, manager.getAppWidgetOptions(id), now))
        }
        for (id in ids(context, QuranWidgetProvider::class.java)) {
            manager.updateAppWidget(id, WidgetViews.quran(context, snapshot, manager.getAppWidgetOptions(id)))
        }
        schedule(context, if (ids(context, PrayerWidgetProvider::class.java).isEmpty()) null else nextRedrawAt(snapshot, now))
    }

    private fun schedule(context: Context, at: Long?) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = PendingIntent.getBroadcast(
            context, TICK_REQUEST,
            Intent(context, WidgetTickReceiver::class.java).setAction(TICK_ACTION),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        alarms.cancel(intent)
        if (at == null) return
        // RTC, not a wake-up: a redraw only matters once the screen is on.
        if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
            alarms.setExact(AlarmManager.RTC, at, intent)
        } else {
            alarms.setWindow(AlarmManager.RTC, at, 60_000, intent)
        }
    }
}
