package com.kev208dev.Surlap

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/** Artifact v2.1 responsive home widget: 2x2 D-Day and 4x2 daily agenda. */
class SurlapWidgetProvider : HomeWidgetProvider() {

    private companion object {
        const val MEDIUM_MIN_WIDTH_DP = 220
        const val HOME_WIDGET_PREFERENCES = "HomeWidgetPreferences"

        val LIGHT_TEXT = 0xFF14131A.toInt()
        val LIGHT_SOFT = 0xFF6E6B7A.toInt()
        val LIGHT_ACCENT = 0xFF5A2DF4.toInt()
        val DARK_TEXT = 0xFFF2F2F6.toInt()
        val DARK_SOFT = 0xFFADADBC.toInt()
        val DARK_ACCENT = 0xFF8B6CFF.toInt()
    }

    private data class DDay(
        val title: String,
        val countdown: String,
        val dateLabel: String,
    )

    private data class AgendaEvent(
        val title: String,
        val time: String,
        val color: Int?,
    )

    private data class NextClass(
        val title: String,
        val time: String,
    )

    private data class WidgetPayload(
        val dark: Boolean,
        val dateLabel: String,
        val dDay: DDay?,
        val events: List<AgendaEvent>,
        val nextClass: NextClass?,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            render(context, appWidgetManager, id, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val widgetData = context.getSharedPreferences(HOME_WIDGET_PREFERENCES, Context.MODE_PRIVATE)
        render(context, appWidgetManager, appWidgetId, widgetData)
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.surlap_widget)
        val launchIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

        val payload = parsePayload(widgetData)
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidth)
        val isMedium = maxOf(minWidth, maxWidth) >= MEDIUM_MIN_WIDTH_DP

        applyTheme(views, payload.dark)
        views.setViewVisibility(R.id.widget_small, if (isMedium) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_medium, if (isMedium) View.VISIBLE else View.GONE)

        if (isMedium) {
            bindMedium(views, payload)
        } else {
            bindSmall(views, payload)
        }

        val description = if (isMedium) {
            "오늘 일정 ${payload.events.size}개${payload.nextClass?.let { ", 다음 수업 ${it.title}" } ?: ""}"
        } else {
            payload.dDay?.let { "${it.title}, ${it.countdown}" } ?: "다가오는 학사 일정 없음"
        }
        views.setCharSequence(R.id.widget_root, "setContentDescription", description)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun applyTheme(views: RemoteViews, dark: Boolean) {
        val text = if (dark) DARK_TEXT else LIGHT_TEXT
        val soft = if (dark) DARK_SOFT else LIGHT_SOFT
        val accent = if (dark) DARK_ACCENT else LIGHT_ACCENT
        val background = if (dark) R.drawable.surlap_widget_bg_dark else R.drawable.surlap_widget_bg_light
        val nextBackground = if (dark) R.drawable.surlap_widget_next_dark else R.drawable.surlap_widget_next_light

        views.setInt(R.id.widget_root, "setBackgroundResource", background)
        views.setInt(R.id.widget_next_class, "setBackgroundResource", nextBackground)

        intArrayOf(
            R.id.widget_small_title,
            R.id.widget_medium_heading,
            R.id.widget_event_0_title,
            R.id.widget_event_1_title,
            R.id.widget_event_2_title,
            R.id.widget_next_class_title,
        ).forEach { views.setTextColor(it, text) }

        intArrayOf(
            R.id.widget_small_eyebrow,
            R.id.widget_small_date,
            R.id.widget_medium_date,
            R.id.widget_event_0_time,
            R.id.widget_event_1_time,
            R.id.widget_event_2_time,
            R.id.widget_events_empty,
            R.id.widget_next_class_time,
        ).forEach { views.setTextColor(it, soft) }

        intArrayOf(
            R.id.widget_small_dday,
            R.id.widget_event_0_dot,
            R.id.widget_event_1_dot,
            R.id.widget_event_2_dot,
            R.id.widget_next_class_label,
        ).forEach { views.setTextColor(it, accent) }
    }

    private fun bindSmall(views: RemoteViews, payload: WidgetPayload) {
        val dDay = payload.dDay
        views.setTextViewText(R.id.widget_small_dday, dDay?.countdown ?: "—")
        views.setTextViewText(R.id.widget_small_title, dDay?.title ?: "다가오는 일정 없음")
        views.setTextViewText(R.id.widget_small_date, dDay?.dateLabel.orEmpty())
    }

    private fun bindMedium(views: RemoteViews, payload: WidgetPayload) {
        views.setTextViewText(R.id.widget_medium_date, payload.dateLabel)

        val rowIds = intArrayOf(R.id.widget_event_0, R.id.widget_event_1, R.id.widget_event_2)
        val dotIds = intArrayOf(R.id.widget_event_0_dot, R.id.widget_event_1_dot, R.id.widget_event_2_dot)
        val timeIds = intArrayOf(R.id.widget_event_0_time, R.id.widget_event_1_time, R.id.widget_event_2_time)
        val titleIds = intArrayOf(R.id.widget_event_0_title, R.id.widget_event_1_title, R.id.widget_event_2_title)
        rowIds.indices.forEach { index ->
            val event = payload.events.getOrNull(index)
            views.setViewVisibility(rowIds[index], if (event == null) View.GONE else View.VISIBLE)
            if (event != null) {
                event.color?.let { views.setTextColor(dotIds[index], it) }
                views.setTextViewText(timeIds[index], event.time.ifBlank { "종일" })
                views.setTextViewText(titleIds[index], event.title)
            }
        }
        views.setViewVisibility(
            R.id.widget_events_empty,
            if (payload.events.isEmpty()) View.VISIBLE else View.GONE,
        )

        val nextClass = payload.nextClass
        views.setViewVisibility(R.id.widget_next_class, if (nextClass == null) View.GONE else View.VISIBLE)
        if (nextClass != null) {
            views.setTextViewText(R.id.widget_next_class_title, nextClass.title)
            views.setTextViewText(R.id.widget_next_class_time, nextClass.time)
        }
    }

    private fun parsePayload(widgetData: SharedPreferences): WidgetPayload {
        val root = widgetData.getString("hs_widget", null)?.let { raw ->
            try {
                JSONObject(raw)
            } catch (_: Throwable) {
                null
            }
        }

        val appearance = root.objectOf("appearance")
        val medium = root.objectOf("medium")
        val dark = when {
            appearance?.has("dark") == true -> appearance.optBoolean("dark", false)
            root?.has("dark") == true -> root.optBoolean("dark", false)
            root.stringOf("theme") == "dark" -> true
            else -> widgetData.getString("theme", "light") == "dark"
        }
        val dateLabel = medium.stringOf("dateLabel", "date")
            .ifBlank { root.stringOf("dateLabel", "today", "date") }
            .ifBlank { widgetData.getString("today", "").orEmpty() }

        return WidgetPayload(
            dark = dark,
            dateLabel = dateLabel,
            dDay = parseDDay(root, widgetData),
            events = parseEvents(root),
            nextClass = parseNextClass(root, widgetData),
        )
    }

    private fun parseDDay(root: JSONObject?, widgetData: SharedPreferences): DDay? {
        val canonical = root.objectOf("small")
        if (canonical != null && canonical.has("available") && !canonical.optBoolean("available")) {
            return null
        }
        if (canonical != null) {
            val title = canonical.stringOf("title", "name")
            if (title.isNotBlank()) {
                val days = canonical.intOf("daysAway", "days")
                val countdown = canonical.stringOf("label", "countdown", "display")
                    .ifBlank { formatDDay(days) }
                val date = canonical.stringOf("dateLabel", "date")
                return DDay(title = title, countdown = countdown, dateLabel = date)
            }
        }

        val value = root?.valueOf("nearestDday", "nearestDDay", "nearestAcademic", "dDay", "dday")
        val obj = value as? JSONObject
        val title = when (value) {
            is JSONObject -> value.stringOf("title", "name", "eventTitle")
            is String -> value
            else -> root.stringOf("ddayTitle", "dDayTitle", "nearestDdayTitle")
        }.ifBlank { widgetData.getString("ddayTitle", "").orEmpty() }
        if (title.isBlank()) return null

        val countdown = obj?.stringOf("countdown", "display", "dDayLabel", "ddayLabel")
            .orEmpty()
            .ifBlank {
                val days = obj?.intOf("daysAway", "days", "count")
                    ?: root.intOf("ddayDays", "dDayDays", "nearestDdayDays")
                formatDDay(days)
            }
        val date = obj?.stringOf("dateLabel", "date", "day")
            .orEmpty()
            .ifBlank { root.stringOf("ddayDateLabel", "ddayDate", "dDayDate") }

        return DDay(title = title, countdown = countdown, dateLabel = date)
    }

    private fun parseEvents(root: JSONObject?): List<AgendaEvent> {
        if (root == null) return emptyList()
        val canonical = root.objectOf("medium")?.arrayOf("events")
            ?: root.arrayOf("todayEvents", "eventsToday", "agenda")
        val source = if (canonical != null) {
            canonical
        } else {
            JSONArray().also { merged ->
                root.arrayOf("allDay")?.copyInto(merged)
                root.arrayOf("timed", "events")?.copyInto(merged)
            }
        }

        val events = ArrayList<AgendaEvent>(3)
        for (index in 0 until source.length()) {
            val item = source.optJSONObject(index) ?: continue
            val title = item.stringOf("title", "name", "t")
            if (title.isBlank()) continue
            val allDay = item.optBoolean("allDay", false)
            val time = item.stringOf("timeLabel", "time", "startTime", "start", "tm")
                .ifBlank { if (allDay) "종일" else "" }
            events += AgendaEvent(
                title = title,
                time = time,
                color = parseColor(item.stringOf("color")),
            )
            if (events.size == 3) break
        }
        return events
    }

    private fun parseNextClass(root: JSONObject?, widgetData: SharedPreferences): NextClass? {
        val canonical = root.objectOf("medium")?.objectOf("nextClass")
        if (canonical != null && canonical.has("available") && !canonical.optBoolean("available")) {
            return null
        }
        val obj = canonical ?: root?.objectOf("nextClass", "upcomingClass")
        val title = obj?.stringOf("title", "name", "subject")
            .orEmpty()
            .ifBlank { root.stringOf("nextClassName", "nextName") }
            .ifBlank { widgetData.getString("nextName", "").orEmpty() }
        if (title.isBlank()) return null
        val start = obj.stringOf("start", "startTime")
        val period = obj?.valueOf("period")?.toString().orEmpty()
        val canonicalTime = when {
            period.isNotBlank() && start.isNotBlank() -> "${period}교시 · $start"
            start.isNotBlank() -> start
            period.isNotBlank() -> "${period}교시"
            else -> ""
        }
        val time = obj?.stringOf("timeLabel", "time", "periodLabel")
            .orEmpty().ifBlank { canonicalTime }
            .ifBlank { root.stringOf("nextClassTime", "nextStart") }
            .ifBlank { widgetData.getString("nextStart", "").orEmpty() }
        return NextClass(title = title, time = time)
    }

    private fun formatDDay(days: Int?): String = when {
        days == null || days == 0 -> "D-DAY"
        days > 0 -> "D-$days"
        else -> "D+${-days}"
    }

    private fun parseColor(raw: String): Int? {
        val hex = raw.removePrefix("#")
        if (hex.length != 6 && hex.length != 8) return null
        return try {
            val value = hex.toLong(16)
            if (hex.length == 6) (0xFF000000L or value).toInt() else value.toInt()
        } catch (_: NumberFormatException) {
            null
        }
    }

    private fun JSONObject?.valueOf(vararg keys: String): Any? {
        if (this == null) return null
        keys.forEach { key ->
            if (has(key) && !isNull(key)) return opt(key)
        }
        return null
    }

    private fun JSONObject?.stringOf(vararg keys: String): String {
        if (this == null) return ""
        keys.forEach { key ->
            val value = opt(key)
            if (value is String && value.isNotBlank()) return value
        }
        return ""
    }

    private fun JSONObject?.intOf(vararg keys: String): Int? {
        if (this == null) return null
        keys.forEach { key ->
            val value = opt(key)
            when (value) {
                is Number -> return value.toInt()
                is String -> value.toIntOrNull()?.let { return it }
            }
        }
        return null
    }

    private fun JSONObject?.objectOf(vararg keys: String): JSONObject? {
        if (this == null) return null
        keys.forEach { key -> optJSONObject(key)?.let { return it } }
        return null
    }

    private fun JSONObject?.arrayOf(vararg keys: String): JSONArray? {
        if (this == null) return null
        keys.forEach { key -> optJSONArray(key)?.let { return it } }
        return null
    }

    private fun JSONArray.copyInto(target: JSONArray) {
        for (index in 0 until length()) target.put(opt(index))
    }
}
