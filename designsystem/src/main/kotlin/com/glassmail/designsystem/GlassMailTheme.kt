package com.glassmail.designsystem

import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.foundation.isSystemInDarkTheme

data class AmbientPalette(val first: Color, val second: Color)
object GlassMailPalette {
    val DarkBase = Color(0xFF090A0D); val DarkSurface = Color(0xFF13161C)
    val LightBase = Color(0xFFF4F6F9); val LightSurface = Color.White
    val Priority = AmbientPalette(Color(0xFF38BDF8), Color(0xFF1E40AF))
    val Updates = AmbientPalette(Color(0xFF0284C7), Color(0xFF0F766E))
    val Newsletters = AmbientPalette(Color(0xFF7C3AED), Color(0xFFBE185D))
    val Personal = AmbientPalette(Color(0xFF1D4ED8), Color(0xFF0284C7))
    val Work = AmbientPalette(Color(0xFF0D9488), Color(0xFF059669))
    val Promotions = AmbientPalette(Color(0xFFD97706), Color(0xFFDC2626))
    val Reminders = AmbientPalette(Color(0xFF6366F1), Color(0xFF8B5CF6))
}
object GlassMotion { const val Fast = 150; const val Standard = 250; const val Chroma = 450 }

@Composable fun GlassMailTheme(dark: Boolean = isSystemInDarkTheme(), ambient: AmbientPalette = GlassMailPalette.Priority, content: @Composable () -> Unit) {
    val scheme = if (dark) darkColorScheme(background = GlassMailPalette.DarkBase, surface = GlassMailPalette.DarkSurface, onBackground = Color(0xFFF2F5F8), onSurface = Color(0xFFF2F5F8), primary = Color(0xFF38BDF8)) else lightColorScheme(background = GlassMailPalette.LightBase, surface = GlassMailPalette.LightSurface, onBackground = Color(0xFF0F172A), onSurface = Color(0xFF0F172A), primary = Color(0xFF0284C7))
    MaterialTheme(colorScheme = scheme, content = content)
}

@Composable fun AmbientCanvas(ambient: AmbientPalette, dark: Boolean, content: @Composable () -> Unit) {
    val first by androidx.compose.animation.animateColorAsState(ambient.first.copy(alpha = if (dark) .20f else .12f), tween(GlassMotion.Chroma), label = "ambientFirst")
    val second by androidx.compose.animation.animateColorAsState(ambient.second.copy(alpha = if (dark) .16f else .10f), tween(GlassMotion.Chroma), label = "ambientSecond")
    Box(Modifier.fillMaxSize().background(Brush.radialGradient(listOf(first, Color.Transparent), center = androidx.compose.ui.geometry.Offset(0f, 0f), radius = 1500f)).background(Brush.radialGradient(listOf(second, Color.Transparent), center = androidx.compose.ui.geometry.Offset(1200f, 900f), radius = 1500f))) { content() }
}
