package app.mathani.mathani.widgets

import android.content.Context
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

/** Sends the watch copy to a paired Wear OS watch over the Data Layer (specs/017
 * contracts/watch-sync.md). Only real changes are sent; nothing happens without Play services. */
object WearSync {
    const val PATH = "/mathani/widgets"
    private const val PREFS = "mathani_wear_sync"

    fun send(context: Context, watch: String) {
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val hash = SnapshotStore.sha256(watch)
        if (prefs.getString("hash", null) == hash) return
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(app) != ConnectionResult.SUCCESS) return
        val made = try {
            JSONObject(watch).getLong("madeAtUtc")
        } catch (e: Exception) {
            return
        }
        val request = PutDataMapRequest.create(PATH).apply {
            dataMap.putString("watch", watch)
            dataMap.putLong("madeAtUtc", made)
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(app).putDataItem(request)
            .addOnSuccessListener { prefs.edit().putString("hash", hash).apply() }
            .addOnFailureListener { Log.d("Mathani", "Wear sync skipped: ${it.message}") }
    }
}
