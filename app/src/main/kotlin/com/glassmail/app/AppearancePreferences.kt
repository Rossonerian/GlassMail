package com.glassmail.app

import android.content.Context
import com.glassmail.designsystem.glass.GlassQuality
import com.glassmail.designsystem.glass.resolveGlassQuality

enum class ThemeChoice { SYSTEM, LIGHT, DARK }

data class AppearanceSettings(
    val theme: ThemeChoice = ThemeChoice.SYSTEM,
    val glassQuality: GlassQuality = GlassQuality.BALANCED,
    val reduceTransparency: Boolean = false,
    val reduceMotion: Boolean = false,
    val showNotificationPreviews: Boolean = false,
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
    )

    fun write(settings: AppearanceSettings) {
        preferences.edit()
            .putString(KEY_THEME, settings.theme.name)
            .putString(KEY_QUALITY, settings.glassQuality.name)
            .putBoolean(KEY_REDUCE_TRANSPARENCY, settings.reduceTransparency)
            .putBoolean(KEY_REDUCE_MOTION, settings.reduceMotion)
            .putBoolean(KEY_NOTIFICATION_PREVIEWS, settings.showNotificationPreviews)
            .apply()
    }

    private companion object {
        const val KEY_THEME = "theme"
        const val KEY_QUALITY = "glass_quality"
        const val KEY_REDUCE_TRANSPARENCY = "reduce_transparency"
        const val KEY_REDUCE_MOTION = "reduce_motion"
        const val KEY_NOTIFICATION_PREVIEWS = "notification_previews"
    }
}
