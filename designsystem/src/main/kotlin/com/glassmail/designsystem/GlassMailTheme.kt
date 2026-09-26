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
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class AmbientPalette(val first: Color, val second: Color)

object GlassMailPalette {
    data class Ramp(private val colors: List<Color>) {
        operator fun get(shade: Int): Color {
            val index = when {
                shade <= 50 -> 0
                shade < 200 -> 1
                shade >= 950 -> 10
                else -> (shade / 100).coerceIn(2, 9)
            }
            return colors[index.coerceIn(0, colors.lastIndex)]
        }
    }

    private fun ramp(vararg hex: Long) = Ramp(hex.map { Color(it.toInt()) })

    val lightText = ramp(0xFFF6F3EE, 0xFFEDE8DE, 0xFFDCD0BC, 0xFFCAB99B, 0xFFB9A179, 0xFFA78A58, 0xFF866E46, 0xFF645335, 0xFF433723, 0xFF211C12, 0xFF110E09)
    val lightBackground = ramp(0xFFF6F3EF, 0xFFEDE6DE, 0xFFDACEBE, 0xFFC8B59D, 0xFFB69D7C, 0xFFA3845C, 0xFF836A49, 0xFF624F37, 0xFF413525, 0xFF211A12, 0xFF100D09)
    val lightPrimary = ramp(0xFFF6F3EE, 0xFFEDE7DE, 0xFFDBCFBD, 0xFFC9B69C, 0xFFB89E7A, 0xFFA68659, 0xFF856B47, 0xFF635036, 0xFF423624, 0xFF211B12, 0xFF110D09)
    val lightSecondary = ramp(0xFFF4F6EF, 0xFFEAEDDE, 0xFFD5DBBD, 0xFFC0C99C, 0xFFABB77B, 0xFF96A45B, 0xFF788448, 0xFF5A6336, 0xFF3C4224, 0xFF1E2112, 0xFF0F1009)
    val lightAccent = ramp(0xFFF4F6EF, 0xFFE8EDDE, 0xFFD2DBBD, 0xFFBBC99C, 0xFFA5B77B, 0xFF8EA45B, 0xFF728448, 0xFF556336, 0xFF394224, 0xFF1C2112, 0xFF0E1009)

    val darkText = ramp(0xFF110E09, 0xFF211B12, 0xFF433723, 0xFF645235, 0xFF866D46, 0xFFA78958, 0xFFB9A079, 0xFFCAB89B, 0xFFDCD0BC, 0xFFEDE7DE, 0xFFF6F3EE)
    val darkBackground = ramp(0xFF100D09, 0xFF211A12, 0xFF413525, 0xFF624F37, 0xFF836A49, 0xFFA3845C, 0xFFB69D7C, 0xFFC8B59D, 0xFFDACEBE, 0xFFEDE6DE, 0xFFF6F3EF)
    val darkPrimary = ramp(0xFF110D09, 0xFF211B12, 0xFF423624, 0xFF635036, 0xFF856B47, 0xFFA68659, 0xFFB89E7A, 0xFFC9B69C, 0xFFDBCFBD, 0xFFEDE7DE, 0xFFF6F3EE)
    val darkSecondary = ramp(0xFF0F1009, 0xFF1E2112, 0xFF3C4224, 0xFF5A6336, 0xFF788448, 0xFF96A45B, 0xFFABB77B, 0xFFC0C99C, 0xFFD5DBBD, 0xFFEAEDDE, 0xFFF4F6EF)
    val darkAccent = ramp(0xFF0E1009, 0xFF1C2112, 0xFF394224, 0xFF556336, 0xFF728448, 0xFF8EA45B, 0xFFA5B77B, 0xFFBBC99C, 0xFFD2DBBD, 0xFFE8EDDE, 0xFFF4F6EF)

    val DarkBase get() = darkBackground[50]
    val DarkSurface get() = darkBackground[100]
    val DarkVariant get() = darkBackground[200]
    val LightBase get() = lightBackground[50]
    val LightSurface get() = lightBackground[100]
    val LightVariant get() = lightBackground[200]

    val Priority = AmbientPalette(Color(0xFFA68659), Color(0xFF856B47))
    val Updates = AmbientPalette(Color(0xFF96A45B), Color(0xFF788448))
    val Newsletters = AmbientPalette(Color(0xFF8EA45B), Color(0xFF556336))
    val Personal = AmbientPalette(Color(0xFFA5B77B), Color(0xFF728448))
    val Work = AmbientPalette(Color(0xFFC0C99C), Color(0xFF5A6336))
    val Promotions = AmbientPalette(Color(0xFFB69D7C), Color(0xFF836A49))
    val Reminders = AmbientPalette(Color(0xFFABB77B), Color(0xFF788448))
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
        primary = GlassMailPalette.darkPrimary[700],
        onPrimary = GlassMailPalette.darkPrimary[100],
        primaryContainer = GlassMailPalette.darkPrimary[300],
        onPrimaryContainer = GlassMailPalette.darkPrimary[900],
        secondary = GlassMailPalette.darkSecondary[700],
        onSecondary = GlassMailPalette.darkSecondary[100],
        secondaryContainer = GlassMailPalette.darkSecondary[200],
        onSecondaryContainer = GlassMailPalette.darkSecondary[950],
        background = GlassMailPalette.darkBackground[50],
        onBackground = GlassMailPalette.darkText[950],
        surface = GlassMailPalette.darkBackground[50],
        onSurface = GlassMailPalette.darkText[950],
        surfaceVariant = GlassMailPalette.darkBackground[100],
        onSurfaceVariant = GlassMailPalette.darkText[800],
        outline = GlassMailPalette.darkBackground[300],
        outlineVariant = GlassMailPalette.darkBackground[200],
        error = Color(0xFFFFB4AB),
    ) else lightColorScheme(
        primary = GlassMailPalette.lightPrimary[700],
        onPrimary = GlassMailPalette.lightPrimary[50],
        primaryContainer = GlassMailPalette.lightSecondary[200],
        onPrimaryContainer = GlassMailPalette.lightText[950],
        secondary = GlassMailPalette.lightSecondary[700],
        onSecondary = GlassMailPalette.lightSecondary[50],
        secondaryContainer = GlassMailPalette.lightSecondary[100],
        onSecondaryContainer = GlassMailPalette.lightText[950],
        background = GlassMailPalette.lightBackground[50],
        onBackground = GlassMailPalette.lightText[950],
        surface = GlassMailPalette.lightBackground[100],
        onSurface = GlassMailPalette.lightText[950],
        surfaceVariant = GlassMailPalette.lightBackground[200],
        onSurfaceVariant = GlassMailPalette.lightText[800],
        outline = GlassMailPalette.lightBackground[400],
        outlineVariant = GlassMailPalette.lightBackground[300],
        error = Color(0xFFB3261E),
    )
    MaterialTheme(colorScheme = scheme, typography = GlassMailTypography, content = content)
}

private val GlassMailTypography = androidx.compose.material3.Typography(
    displayLarge = TextStyle(fontFamily = FontFamily(Font(R.font.lobster_two_bold_italic, FontWeight.Bold, FontStyle.Italic)), fontSize = 44.sp, lineHeight = 52.sp, fontWeight = FontWeight.Bold, fontStyle = FontStyle.Italic),
    displayMedium = TextStyle(fontFamily = FontFamily(Font(R.font.lobster_two_bold_italic, FontWeight.Bold, FontStyle.Italic)), fontSize = 36.sp, lineHeight = 44.sp, fontWeight = FontWeight.Bold, fontStyle = FontStyle.Italic),
    displaySmall = TextStyle(fontFamily = FontFamily(Font(R.font.lobster_two_bold_italic, FontWeight.Bold, FontStyle.Italic)), fontSize = 30.sp, lineHeight = 38.sp, fontWeight = FontWeight.Bold, fontStyle = FontStyle.Italic),
    headlineLarge = TextStyle(fontFamily = FontFamily(Font(R.font.lobster_two_bold_italic, FontWeight.Bold, FontStyle.Italic)), fontSize = 32.sp, lineHeight = 40.sp, fontWeight = FontWeight.Bold, fontStyle = FontStyle.Italic),
    headlineMedium = TextStyle(fontFamily = FontFamily(Font(R.font.trirong_regular, FontWeight.Normal)), fontSize = 26.sp, lineHeight = 34.sp),
    headlineSmall = TextStyle(fontFamily = FontFamily(Font(R.font.trirong_regular, FontWeight.Normal)), fontSize = 22.sp, lineHeight = 30.sp),
    titleLarge = TextStyle(
        fontFamily = FontFamily(Font(R.font.trirong_regular, FontWeight.Normal)),
        fontSize = 22.sp,
        lineHeight = 28.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = (-0.3).sp,
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily(Font(R.font.trirong_regular, FontWeight.Normal)),
        fontSize = 16.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.Normal,
    ),
    titleSmall = TextStyle(
        fontFamily = FontFamily(Font(R.font.trirong_regular, FontWeight.Normal)),
        fontSize = 14.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.Normal,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily(Font(R.font.maitree_regular, FontWeight.Normal)),
        fontSize = 15.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.1.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily(Font(R.font.maitree_regular, FontWeight.Normal)),
        fontSize = 14.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.15.sp,
    ),
    bodySmall = TextStyle(
        fontFamily = FontFamily(Font(R.font.maitree_regular, FontWeight.Normal)),
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.2.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily(Font(R.font.maitree_regular, FontWeight.Normal)),
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.1.sp,
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily(Font(R.font.maitree_regular, FontWeight.Normal)),
        fontSize = 12.sp,
        lineHeight = 16.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 0.2.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily(Font(R.font.maitree_regular, FontWeight.Normal)),
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
