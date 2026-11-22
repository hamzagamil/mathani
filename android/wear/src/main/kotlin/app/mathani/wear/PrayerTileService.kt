package app.mathani.wear

import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture

/** The prayer tile (specs/017 User Story 4): the place and today's times, the next highlighted.
 * One timeline entry per prayer, so the highlight moves on time without the phone (R7). */
class PrayerTileService : TileService() {
    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> =
        CallbackToFutureAdapter.getFuture { completer ->
            completer.set(
                TileBuilders.Tile.Builder()
                    .setResourcesVersion(RESOURCES)
                    .setTileTimeline(timeline(CopyStore(this).copy(), System.currentTimeMillis()))
                    .build()
            )
            "prayer tile"
        }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<ResourceBuilders.Resources> = CallbackToFutureAdapter.getFuture { completer ->
        completer.set(ResourceBuilders.Resources.Builder().setVersion(RESOURCES).build())
        "prayer tile resources"
    }

    private fun timeline(copy: WatchCopy?, now: Long): TimelineBuilders.Timeline {
        val builder = TimelineBuilders.Timeline.Builder()
        val block = copy?.prayer
        if (copy == null || block == null) {
            builder.addTimelineEntry(entry(message(copy?.label("setPlaceWatch")?.ifEmpty { null } ?: getString(R.string.open_phone)), null, null))
            return builder.build()
        }
        for (slot in prayerSlots(block, now)) {
            val layout = slot.next?.let { day(copy, block, it) } ?: message(copy.label("openToUpdate"))
            builder.addTimelineEntry(entry(layout, slot.start, slot.end.takeIf { it != Long.MAX_VALUE }))
        }
        return builder.build()
    }

    private fun entry(layout: LayoutElementBuilders.LayoutElement, start: Long?, end: Long?): TimelineBuilders.TimelineEntry {
        val e = TimelineBuilders.TimelineEntry.Builder()
            .setLayout(LayoutElementBuilders.Layout.Builder().setRoot(clickable(layout)).build())
        if (start != null) {
            val validity = TimelineBuilders.TimeInterval.Builder().setStartMillis(start)
            if (end != null) validity.setEndMillis(end)
            e.setValidity(validity.build())
        }
        return e.build()
    }

    /** A tap opens the watch app (FR-021). */
    private fun clickable(content: LayoutElementBuilders.LayoutElement) = LayoutElementBuilders.Box.Builder()
        .setWidth(expand()).setHeight(expand())
        .setModifiers(
            ModifiersBuilders.Modifiers.Builder().setClickable(
                ModifiersBuilders.Clickable.Builder().setId("open").setOnClick(
                    ActionBuilders.LaunchAction.Builder().setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName(MainActivity::class.java.name)
                            .build()
                    ).build()
                ).build()
            ).build()
        )
        .addContent(content)
        .build()

    private fun text(value: String, size: Float, color: Int, bold: Boolean = false) = LayoutElementBuilders.Text.Builder()
        .setText(value)
        .setMaxLines(1)
        .setFontStyle(
            LayoutElementBuilders.FontStyle.Builder()
                .setSize(sp(size))
                .setColor(argb(color))
                .setWeight(if (bold) LayoutElementBuilders.FONT_WEIGHT_BOLD else LayoutElementBuilders.FONT_WEIGHT_NORMAL)
                .build()
        )
        .build()

    private fun message(value: String) = text(value, 14f, WHITE)

    private fun day(copy: WatchCopy, block: PrayerBlock, next: PrayerEntry): LayoutElementBuilders.LayoutElement {
        val (label, entries) = block.dayOf(next.atUtc)
        val column = LayoutElementBuilders.Column.Builder()
            .addContent(text(block.place, 15f, WHITE, bold = true))
            .addContent(text(label, 12f, MUTED))
            .addContent(LayoutElementBuilders.Spacer.Builder().setHeight(dp(4f)).build())
        for (e in entries) {
            val isNext = e == next
            val color = if (isNext) ACCENT else WHITE
            // In Arabic the time goes first, as the row reads right to left.
            val row = if (copy.rtl) "${e.time}   ${e.name}" else "${e.name}   ${e.time}"
            column.addContent(text(row, 14f, color, bold = isNext))
        }
        return column.build()
    }

    companion object {
        private const val RESOURCES = "1"
        private const val WHITE = 0xFFEDE4D3.toInt()
        private const val MUTED = 0xFFA7AEBD.toInt()
        private const val ACCENT = 0xFFD9BD82.toInt()
    }
}
