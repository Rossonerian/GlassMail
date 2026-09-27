import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;

import 'glass_material.dart';

enum GlassMailTier { full, balanced, light, off }

class MailGlassAccessibility extends InheritedWidget {
  const MailGlassAccessibility({
    required this.glassTier,
    required this.reduceTransparency,
    required super.child,
    super.key,
  });

  final GlassMailTier glassTier;
  final bool reduceTransparency;

  static bool reduceTransparencyOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MailGlassAccessibility>()
          ?.reduceTransparency ??
      false;

  static GlassMailTier tierOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MailGlassAccessibility>()
          ?.glassTier ??
      GlassMailTier.balanced;

  @override
  bool updateShouldNotify(MailGlassAccessibility oldWidget) =>
      glassTier != oldWidget.glassTier ||
      reduceTransparency != oldWidget.reduceTransparency;
}

/// GlassMail-owned boundary around the optional renderer and opaque fallback.
class GlassMailGlass extends StatelessWidget {
  const GlassMailGlass({
    required this.child,
    required this.material,
    this.tier,
    this.reduceTransparency = false,
    this.padding,
    this.alignment,
    super.key,
  });

  final Widget child;
  final GlassMaterial material;
  final GlassMailTier? tier;
  final bool reduceTransparency;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final activeTier = tier ?? MailGlassAccessibility.tierOf(context);
    final useOpaqueFallback =
        activeTier == GlassMailTier.off ||
        reduceTransparency ||
        MailGlassAccessibility.reduceTransparencyOf(context) ||
        highContrast;
    final radius = BorderRadius.circular(material.cornerRadius);
    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: alignment == null
          ? child
          : Align(alignment: alignment!, child: child),
    );

    if (useOpaqueFallback) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: radius,
          border: Border.all(color: colors.outlineVariant),
          boxShadow: _shadows(material, colors),
        ),
        child: ClipRRect(borderRadius: radius, child: content),
      );
    }

    final tint = material.tint ?? colors.surface;
    final quality = switch (activeTier) {
      GlassMailTier.full => liquid.GlassQuality.premium,
      GlassMailTier.balanced => liquid.GlassQuality.standard,
      GlassMailTier.light => liquid.GlassQuality.minimal,
      GlassMailTier.off => liquid.GlassQuality.minimal,
    };
    final settings = liquid.LiquidGlassSettings(
      // Native Dp values map directly to Flutter logical pixels.
      blur: activeTier == GlassMailTier.light
          ? math.min(material.blur, 12)
          : material.blur,
      glassColor: tint.withValues(alpha: material.opacity),
      thickness: material.refractionHeight + material.refraction * 12,
      refractiveIndex: 1 + material.refraction * .2,
      chromaticAberration: material.dispersion * 4,
      lightAngle: material.specularAngle,
      lightIntensity: material.specularIntensity,
      ambientStrength: material.luminanceAdaptation,
      ambientRim: material.rimLight,
      saturation: material.saturation,
      glowIntensity: material.interactionStrength,
      specularSharpness: material.highlightFalloff >= 6
          ? liquid.GlassSpecularSharpness.sharp
          : material.highlightFalloff <= 3
          ? liquid.GlassSpecularSharpness.soft
          : liquid.GlassSpecularSharpness.medium,
      shadow: _shadows(material, colors),
      // Package API has no direct inner-shadow, so it is retained in the
      // contract and handled by future app-owned decoration where required.
      bodyMode: liquid.GlassBodyMode.clear,
    );

    return liquid.GlassContainer(
      shape: liquid.LiquidRoundedSuperellipse(
        borderRadius: material.cornerRadius,
      ),
      settings: settings,
      useOwnLayer: true,
      quality: quality,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  static List<BoxShadow> _shadows(GlassMaterial material, ColorScheme colors) {
    if (material.shadow <= 0) return const [];
    return [
      BoxShadow(
        color: colors.shadow.withValues(alpha: .12),
        blurRadius: material.shadow,
        offset: Offset(0, material.shadow * .24),
      ),
    ];
  }
}
