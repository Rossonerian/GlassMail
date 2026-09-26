package com.glassmail.app

import android.content.Context
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.resolveGlassQuality

enum class ThemeChoice { SYSTEM, LIGHT, DARK }
enum class SwipeAction { MARK_READ, ARCHIVE, DELETE, STAR }

data class AppearanceSettings(
    val theme: ThemeChoice = ThemeChoice.SYSTEM,
    val glassQuality: GlassQuality = GlassQuality.BALANCED,
    val reduceTransparency: Boolean = false,
    val reduceMotion: Boolean = false,
    val showNotificationPreviews: Boolean = false,
    val shortSwipeLeft: SwipeAction = SwipeAction.ARCHIVE,
    val longSwipeLeft: SwipeAction = SwipeAction.DELETE,
    val shortSwipeRight: SwipeAction = SwipeAction.MARK_READ,
    val longSwipeRight: SwipeAction = SwipeAction.STAR,
    val selectedAccountId: String? = null,
    val unifiedInbox: Boolean = false,
    val sendDelaySeconds: Int = 10,
)

class AppearancePreferences(context: Context) {
    private val preferences = context.getSharedPreferences("glassmail_appearance", Context.MODE_PRIVATE)

    fun read(): AppearanceSettings = AppearanceSettings(
        theme = runCatching { ThemeChoice.valueOf(preferences.getString(KEY_THEME, ThemeChoice.SYSTEM.name)!!) }.getOrDefault(ThemeChoice.SYSTEM),
        glassQuality = resolveGlassQuality(preferences.getString(KEY_QUALITY, GlassQuality.BALANCED.name).let { stored ->
            when (stored) {
                "AUTOMATIC" -> GlassQuality.BALANCED
                "LIQUID" -> GlassQuality.FULL
                "BLUR" -> GlassQuality.LIGHT
                "TRANSPARENT" -> GlassQuality.OFF
                else -> runCatching { GlassQuality.valueOf(stored ?: GlassQuality.BALANCED.name) }
                    .getOrDefault(GlassQuality.BALANCED)
            }
        }),
        reduceTransparency = preferences.getBoolean(KEY_REDUCE_TRANSPARENCY, false),
        reduceMotion = preferences.getBoolean(KEY_REDUCE_MOTION, false),
        showNotificationPreviews = preferences.getBoolean(KEY_NOTIFICATION_PREVIEWS, false),
        shortSwipeLeft = readSwipe(KEY_SHORT_LEFT, SwipeAction.ARCHIVE),
        longSwipeLeft = readSwipe(KEY_LONG_LEFT, SwipeAction.DELETE),
        shortSwipeRight = readSwipe(KEY_SHORT_RIGHT, SwipeAction.MARK_READ),
        longSwipeRight = readSwipe(KEY_LONG_RIGHT, SwipeAction.STAR),
        selectedAccountId = preferences.getString(KEY_SELECTED_ACCOUNT, null),
        unifiedInbox = preferences.getBoolean(KEY_UNIFIED_INBOX, false),
        sendDelaySeconds = preferences.getInt(KEY_SEND_DELAY, 10).takeIf { it in setOf(5, 10, 15, 30) } ?: 10,
    )

    fun write(settings: AppearanceSettings) {
        val editor = preferences.edit()
            .putString(KEY_THEME, settings.theme.name)
            .putString(KEY_QUALITY, settings.glassQuality.name)
            .putBoolean(KEY_REDUCE_TRANSPARENCY, settings.reduceTransparency)
            .putBoolean(KEY_REDUCE_MOTION, settings.reduceMotion)
            .putBoolean(KEY_NOTIFICATION_PREVIEWS, settings.showNotificationPreviews)
            .putString(KEY_SHORT_LEFT, settings.shortSwipeLeft.name)
            .putString(KEY_LONG_LEFT, settings.longSwipeLeft.name)
            .putString(KEY_SHORT_RIGHT, settings.shortSwipeRight.name)
            .putString(KEY_LONG_RIGHT, settings.longSwipeRight.name)
            .putBoolean(KEY_UNIFIED_INBOX, settings.unifiedInbox)
            .putInt(KEY_SEND_DELAY, settings.sendDelaySeconds.coerceIn(5, 30))
        if (settings.selectedAccountId == null) editor.remove(KEY_SELECTED_ACCOUNT) else editor.putString(KEY_SELECTED_ACCOUNT, settings.selectedAccountId)
        editor.apply()
    }

    private fun readSwipe(key: String, fallback: SwipeAction): SwipeAction =
        runCatching { SwipeAction.valueOf(preferences.getString(key, fallback.name)!!) }.getOrDefault(fallback)

    private companion object {
        const val KEY_THEME = "theme"
        const val KEY_QUALITY = "glass_quality"
        const val KEY_REDUCE_TRANSPARENCY = "reduce_transparency"
        const val KEY_REDUCE_MOTION = "reduce_motion"
        const val KEY_NOTIFICATION_PREVIEWS = "notification_previews"
        const val KEY_SHORT_LEFT = "swipe_short_left"
        const val KEY_LONG_LEFT = "swipe_long_left"
        const val KEY_SHORT_RIGHT = "swipe_short_right"
        const val KEY_LONG_RIGHT = "swipe_long_right"
        const val KEY_SELECTED_ACCOUNT = "selected_account_id"
        const val KEY_UNIFIED_INBOX = "unified_inbox"
        const val KEY_SEND_DELAY = "send_delay_seconds"
    }
}
