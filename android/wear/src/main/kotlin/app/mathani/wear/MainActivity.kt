package app.mathani.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import kotlinx.coroutines.delay

/** Mathani on Wear OS (specs/017 FR-021): one list with today's prayer times, the next one marked.
 * Everything else stays on the phone. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { TodayScreen() } }
    }
}

@Composable
private fun TodayScreen() {
    val context = androidx.compose.ui.platform.LocalContext.current
    var copy by remember { mutableStateOf(CopyStore(context).copy()) }
    var now by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        runCatching { SnapshotListenerService.fetchLast(context) }
        while (true) {
            copy = CopyStore(context).copy()
            now = System.currentTimeMillis()
            delay(30_000)
        }
    }
    val c = copy
    val direction = if (c?.rtl == true) LayoutDirection.Rtl else LayoutDirection.Ltr
    CompositionLocalProvider(LocalLayoutDirection provides direction) {
        val block = c?.prayer
        val next = block?.takeUnless { it.isExpired(now) }?.nextEntry(now)
        ScalingLazyColumn(modifier = Modifier.fillMaxWidth()) {
            if (c == null || block == null || next == null) {
                item {
                    Text(
                        text = when {
                            c == null -> stringResource(R.string.open_phone)
                            block != null && block.isExpired(now) -> c.label("openToUpdate")
                            else -> c.label("setPlaceWatch")
                        },
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(16.dp),
                    )
                }
                return@ScalingLazyColumn
            }
            val (label, day) = block.dayOf(next.atUtc)
            item { Text(block.place, style = MaterialTheme.typography.title3, maxLines = 1) }
            item { Text(label, style = MaterialTheme.typography.caption2) }
            for (entry in day) {
                item {
                    val isNext = entry == next
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        val weight = if (isNext) FontWeight.Bold else FontWeight.Normal
                        val color = if (isNext) MaterialTheme.colors.primary else MaterialTheme.colors.onBackground
                        Text(entry.name, fontWeight = weight, color = color)
                        Text(entry.time, fontWeight = weight, color = color)
                    }
                }
            }
        }
    }
}
