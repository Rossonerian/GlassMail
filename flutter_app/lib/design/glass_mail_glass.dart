import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'glass_material.dart';

enum GlassMailTier { full, balanced, lite, off }

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

@immutable
class _GlassSettingsKey {
  const _GlassSettingsKey(this.material, this.tier, this.tint);
  final GlassMaterial material;
  final GlassMailTier tier;
  final Color tint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _GlassSettingsKey &&
          other.material == material &&
          other.tier == tier &&
          other.tint == tint);

  @override
  int get hashCode => Object.hash(material, tier, tint);
}

final _settingsCache = <_GlassSettingsKey, LiquidGlassSettings>{};

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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    var activeTier = tier ?? MailGlassAccessibility.tierOf(context);
    if (disableAnimations && activeTier == GlassMailTier.full) {
      activeTier = GlassMailTier.balanced;
    }

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
    final key = _GlassSettingsKey(material, activeTier, tint);
    
    final settings = _settingsCache.putIfAbsent(
      key,
      () => LiquidGlassSettings(
        blur: activeTier == GlassMailTier.lite
            ? (material.blur > 12 ? 12.0 : material.blur)
            : material.blur,
        glassColor: tint.withValues(alpha: material.opacity),
        thickness: activeTier == GlassMailTier.full 
            ? material.refractionHeight + material.refraction * 12
            : material.refractionHeight, 
        refractiveIndex: activeTier == GlassMailTier.full 
            ? 1 + material.refraction * 0.2
            : 1 + material.refraction * 0.1, // Less refraction in balanced
        chromaticAberration: activeTier == GlassMailTier.full ? material.dispersion * 4 : 0.0,
        lightAngle: material.specularAngle,
        lightIntensity: activeTier == GlassMailTier.full ? material.specularIntensity : material.specularIntensity * 0.5,
        ambientStrength: material.luminanceAdaptation,
        saturation: material.saturation,
      ),
    );

    final shape = LiquidRoundedSuperellipse(borderRadius: material.cornerRadius);
    final shadows = _shadows(material, colors);

    if (activeTier == GlassMailTier.lite) {
      // FakeGlass doesn't use auto, it requires wrapping if needed, but FakeGlass IS the highly performant fallback.
      // FakeGlass doesn't need a LiquidGlassLayer parent, it uses platform BackdropFilter internally.
      return FakeGlass(
        shape: shape,
        settings: settings,
        shadows: shadows,
        child: content,
      );
    }

    return LiquidGlass.auto(
      shape: shape,
      settings: settings,
      shadows: shadows,
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
