package app.mathani.wear

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.tasks.await

/** Receives the watch copy from the phone (specs/017 contracts/watch-sync.md), keeps the newest,
 * and asks the complications and the tile to redraw. */
class SnapshotListenerService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        var changed = false
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED || event.dataItem.uri.path != PATH) continue
            val json = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("watch") ?: continue
            if (CopyStore(this).offer(json)) changed = true
        }
        if (changed) redrawAll(this)
    }

    companion object {
        const val PATH = "/mathani/widgets"

        fun redrawAll(context: Context) {
            for (service in listOf(PrayerComplicationService::class.java, KhatmaComplicationService::class.java)) {
                ComplicationDataSourceUpdateRequester.create(context, ComponentName(context, service)).requestUpdateAll()
            }
            TileService.getUpdater(context).requestUpdate(PrayerTileService::class.java)
        }

        /** First run, or a copy missed while the app was not installed: read the last item. */
        suspend fun fetchLast(context: Context) {
            val store = CopyStore(context)
            val items = Wearable.getDataClient(context).getDataItems(Uri.parse("wear://*$PATH")).await()
            try {
                var changed = false
                for (item in items) {
                    val json = DataMapItem.fromDataItem(item).dataMap.getString("watch") ?: continue
                    if (store.offer(json)) changed = true
                }
                if (changed) redrawAll(context)
            } finally {
                items.release()
            }
        }
    }
}
