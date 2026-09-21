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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class AmbientPalette(val first: Color, val second: Color)
object GlassMailPalette {
    val DarkBase = Color(0xFF090A0D); val DarkSurface = Color(0xFF13161C); val DarkVariant = Color(0xFF1B202A)
    val LightBase = Color(0xFFF4F6F9); val LightSurface = Color.White; val LightVariant = Color(0xFFE2E8F0)
    val Priority = AmbientPalette(Color(0xFF38BDF8), Color(0xFF1E40AF))
    val Updates = AmbientPalette(Color(0xFF0284C7), Color(0xFF0F766E))
    val Newsletters = AmbientPalette(Color(0xFF7C3AED), Color(0xFFBE185D))
    val Personal = AmbientPalette(Color(0xFF1D4ED8), Color(0xFF0284C7))
    val Work = AmbientPalette(Color(0xFF0D9488), Color(0xFF059669))
    val Promotions = AmbientPalette(Color(0xFFD97706), Color(0xFFDC2626))
    val Reminders = AmbientPalette(Color(0xFF6366F1), Color(0xFF8B5CF6))
}

object GlassSpacing {
    val xxs = 2.dp
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val base = 16.dp
    val lg = 20.dp
    val xl = 24.dp
    val xxl = 32.dp
    val xxxl = 48.dp
}

object GlassRadius {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val card = 20.dp
    val innerLens = 22.dp
    val dialog = 28.dp
    val dock = 30.dp
    val pill = 999.dp
}

object GlassIconSize {
    val xs = 14.dp
    val sm = 18.dp
    val md = 22.dp
    val lg = 28.dp
    val xl = 48.dp
}

object GlassElevation {
    val level0 = 0.dp
    val level1 = 2.dp
    val level2 = 4.dp
    val level3 = 8.dp
    val level4 = 16.dp
}

object GlassMotion {
    const val Fast = 150
    const val Standard = 250
    const val Chroma = 450
    const val Morph = 320

    val SpringSubtle = androidx.compose.animation.core.spring<Float>(
        stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow,
        dampingRatio = 0.88f,
    )
    val SpringBouncy = androidx.compose.animation.core.spring<Float>(
        stiffness = androidx.compose.animation.core.Spring.StiffnessMedium,
        dampingRatio = 0.75f,
    )
    val SpringDock = androidx.compose.animation.core.spring<androidx.compose.ui.unit.Dp>(
        stiffness = androidx.compose.animation.core.Spring.StiffnessMedium,
        dampingRatio = 0.82f,
    )
}

@Composable fun GlassMailTheme(dark: Boolean = isSystemInDarkTheme(), ambient: AmbientPalette = GlassMailPalette.Priority, content: @Composable () -> Unit) {
    val scheme = if (dark) darkColorScheme(
        primary = Color(0xFF38BDF8), onPrimary = Color(0xFF001E2C), primaryContainer = Color(0xFF38BDF8), onPrimaryContainer = Color(0xFF001E2C),
        secondary = Color(0xFFB8C4FF), onSecondary = Color(0xFF002584), secondaryContainer = Color(0xFF173BAB), onSecondaryContainer = Color(0xFFA0B1FF),
        background = GlassMailPalette.DarkBase, onBackground = Color(0xFFF2F5F8), surface = GlassMailPalette.DarkSurface, onSurface = Color(0xFFF2F5F8),
        surfaceVariant = GlassMailPalette.DarkVariant, onSurfaceVariant = Color(0xFF94A3B8), outline = Color(0xFF64748B), outlineVariant = Color(0xFF303844), error = Color(0xFFFFB4AB),
    ) else lightColorScheme(
        primary = Color(0xFF0284C7), onPrimary = Color.White, primaryContainer = Color(0xFFBAE6FD), onPrimaryContainer = Color(0xFF0F172A),
        secondary = Color(0xFF1D4ED8), onSecondary = Color.White, secondaryContainer = Color(0xFFDBEAFE), onSecondaryContainer = Color(0xFF0F172A),
        background = GlassMailPalette.LightBase, onBackground = Color(0xFF0F172A), surface = GlassMailPalette.LightSurface, onSurface = Color(0xFF0F172A),
        surfaceVariant = GlassMailPalette.LightVariant, onSurfaceVariant = Color(0xFF64748B), outline = Color(0xFF64748B), outlineVariant = Color(0xFFCBD5E1), error = Color(0xFFB91C1C),
    )
    MaterialTheme(colorScheme = scheme, typography = GlassMailTypography, content = content)
}

private val GlassMailTypography = androidx.compose.material3.Typography(
    titleLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.SemiBold, letterSpacing = (-0.33).sp),
    titleMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 15.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 15.sp, lineHeight = 22.sp),
    bodyMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 13.sp, lineHeight = 18.sp),
    bodySmall = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 12.sp, lineHeight = 16.sp),
    labelLarge = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.24.sp),
    labelMedium = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 10.sp, lineHeight = 14.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.4.sp),
    labelSmall = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 9.sp, lineHeight = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.54.sp),
)

@Composable fun AmbientCanvas(ambient: AmbientPalette, dark: Boolean, content: @Composable () -> Unit) {
    val first by androidx.compose.animation.animateColorAsState(ambient.first.copy(alpha = if (dark) .08f else .05f), tween(GlassMotion.Chroma), label = "ambientFirst")
    val second by androidx.compose.animation.animateColorAsState(ambient.second.copy(alpha = if (dark) .06f else .04f), tween(GlassMotion.Chroma), label = "ambientSecond")
    Box(Modifier.fillMaxSize().background(if (dark) GlassMailPalette.DarkBase else GlassMailPalette.LightBase).background(Brush.radialGradient(listOf(first, Color.Transparent), center = androidx.compose.ui.geometry.Offset(1200f, -120f), radius = 900f)).background(Brush.radialGradient(listOf(second, Color.Transparent), center = androidx.compose.ui.geometry.Offset(-160f, 1700f), radius = 1000f))) { content() }
}
