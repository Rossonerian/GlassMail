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
    val DarkBase = Color(0xFF141514)
    val DarkSurface = Color(0xFF1B1C1A)
    val DarkVariant = Color(0xFF242623)

    val LightBase = Color(0xFFFBF9F5)
    val LightSurface = Color(0xFFFFFFFF)
    val LightVariant = Color(0xFFF2EFE9)

    val Priority = AmbientPalette(Color(0xFF4C735F), Color(0xFF334F41))
    val Updates = AmbientPalette(Color(0xFF5E7A6E), Color(0xFF3E5A4F))
    val Newsletters = AmbientPalette(Color(0xFF7A6B8A), Color(0xFF4F435C))
    val Personal = AmbientPalette(Color(0xFF4B7260), Color(0xFF2C4E3D))
    val Work = AmbientPalette(Color(0xFF3F6354), Color(0xFF254236))
    val Promotions = AmbientPalette(Color(0xFF946F4B), Color(0xFF6B4E32))
    val Reminders = AmbientPalette(Color(0xFF566B7A), Color(0xFF394C59))
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
    val innerLens = 24.dp
    val dialog = 28.dp
    val dock = 32.dp
    val chip = 10.dp
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

@Composable
fun GlassMailTheme(
    dark: Boolean = isSystemInDarkTheme(),
    ambient: AmbientPalette = GlassMailPalette.Priority,
    content: @Composable () -> Unit,
) {
    val scheme = if (dark) darkColorScheme(
        primary = Color(0xFF90B4A2),
        onPrimary = Color(0xFF13271D),
        primaryContainer = Color(0xFF2D4538),
        onPrimaryContainer = Color(0xFFD2E6DB),
        secondary = Color(0xFFB5C2B9),
        onSecondary = Color(0xFF212C25),
        secondaryContainer = Color(0xFF37433C),
        onSecondaryContainer = Color(0xFFD1DDD4),
        background = GlassMailPalette.DarkBase,
        onBackground = Color(0xFFEDEDEA),
        surface = GlassMailPalette.DarkSurface,
        onSurface = Color(0xFFEDEDEA),
        surfaceVariant = GlassMailPalette.DarkVariant,
        onSurfaceVariant = Color(0xFFA6ACA4),
        outline = Color(0xFF383B36),
        outlineVariant = Color(0xFF282B27),
        error = Color(0xFFCF6679),
    ) else lightColorScheme(
        primary = Color(0xFF3A5D4C),
        onPrimary = Color.White,
        primaryContainer = Color(0xFFD6E6DC),
        onPrimaryContainer = Color(0xFF13281E),
        secondary = Color(0xFF526357),
        onSecondary = Color.White,
        secondaryContainer = Color(0xFFD5E8D9),
        onSecondaryContainer = Color(0xFF101F16),
        background = GlassMailPalette.LightBase,
        onBackground = Color(0xFF1A1C19),
        surface = GlassMailPalette.LightSurface,
        onSurface = Color(0xFF1A1C19),
        surfaceVariant = GlassMailPalette.LightVariant,
        onSurfaceVariant = Color(0xFF59615A),
        outline = Color(0xFFD2CEC6),
        outlineVariant = Color(0xFFE5E1D9),
        error = Color(0xFFBA1A1A),
    )
    MaterialTheme(colorScheme = scheme, typography = GlassMailTypography, content = content)
}

private val GlassMailTypography = androidx.compose.material3.Typography(
    titleLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = (-0.3).sp,
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 16.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.SemiBold,
    ),
    titleSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.Medium,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 15.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.1.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.15.sp,
    ),
    bodySmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.2.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.1.sp,
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.2.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 11.sp,
        lineHeight = 14.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.2.sp,
    ),
)

@Composable
fun AmbientCanvas(ambient: AmbientPalette, dark: Boolean, content: @Composable () -> Unit) {
    val first by androidx.compose.animation.animateColorAsState(
        ambient.first.copy(alpha = if (dark) .12f else .08f),
        tween(GlassMotion.Chroma),
        label = "ambientFirst",
    )
    val second by androidx.compose.animation.animateColorAsState(
        ambient.second.copy(alpha = if (dark) .09f else .06f),
        tween(GlassMotion.Chroma),
        label = "ambientSecond",
    )
    Box(
        Modifier
            .fillMaxSize()
            .background(if (dark) GlassMailPalette.DarkBase else GlassMailPalette.LightBase)
            .background(
                Brush.radialGradient(
                    listOf(first, Color.Transparent),
                    center = androidx.compose.ui.geometry.Offset(1200f, -120f),
                    radius = 900f,
                ),
            )
            .background(
                Brush.radialGradient(
                    listOf(second, Color.Transparent),
                    center = androidx.compose.ui.geometry.Offset(-160f, 1700f),
                    radius = 1000f,
                ),
            ),
    ) { content() }
}
