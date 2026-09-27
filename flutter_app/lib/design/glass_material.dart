import 'package:flutter/material.dart';

/// GlassMail's native 16-field material contract, measured in logical pixels
/// for distances and normalized values for optical strengths.
///
/// The values intentionally stay app-owned: the Flutter glass renderer uses a
/// different model, so [GlassMailGlass] performs an explicit best-effort map.
@immutable
class GlassMaterial {
  const GlassMaterial({
    this.blur = 18,
    this.saturation = 1.05,
    this.tint,
    this.opacity = .52,
    this.refraction = .24,
    this.refractionHeight = 8,
    this.dispersion = .16,
    this.rimLight = .38,
    this.specularIntensity = .46,
    this.specularAngle = -.785,
    this.highlightFalloff = 4,
    this.shadow = 10,
    this.cornerRadius = 20,
    this.innerShadow = 0,
    this.interactionStrength = .28,
    this.luminanceAdaptation = .35,
  });

  final double blur;
  final double saturation;
  final Color? tint;
  final double opacity;
  final double refraction;
  final double refractionHeight;
  final double dispersion;
  final double rimLight;
  final double specularIntensity;
  final double specularAngle;
  final double highlightFalloff;
  final double shadow;
  final double cornerRadius;
  final double innerShadow;
  final double interactionStrength;
  final double luminanceAdaptation;
}

abstract final class GlassPresets {
  static const navigation = GlassMaterial(
    blur: 20,
    opacity: .48,
    refraction: .22,
    dispersion: .14,
    rimLight: .40,
    specularIntensity: .45,
    shadow: 14,
    cornerRadius: 30,
  );
  static const toolbar = GlassMaterial(
    blur: 16,
    opacity: .50,
    refraction: .18,
    dispersion: .12,
    rimLight: .35,
    specularIntensity: .40,
    shadow: 10,
    cornerRadius: 20,
  );
  static const search = GlassMaterial(
    blur: 16,
    opacity: .46,
    refraction: .20,
    dispersion: .15,
    rimLight: .36,
    specularIntensity: .42,
    shadow: 8,
    cornerRadius: 16,
  );
  static const floatingAction = GlassMaterial(
    blur: 24,
    opacity: .54,
    refraction: .32,
    dispersion: .22,
    rimLight: .48,
    specularIntensity: .60,
    shadow: 18,
    cornerRadius: 28,
  );
  static const bottomBar = GlassMaterial(
    blur: 22,
    opacity: .52,
    refraction: .24,
    dispersion: .16,
    rimLight: .38,
    specularIntensity: .44,
    shadow: 16,
    cornerRadius: 24,
  );
  static const sheet = GlassMaterial(
    blur: 28,
    opacity: .62,
    refraction: .26,
    dispersion: .18,
    rimLight: .42,
    specularIntensity: .48,
    shadow: 24,
    cornerRadius: 28,
  );
  static const dialog = GlassMaterial(
    blur: 26,
    opacity: .65,
    refraction: .28,
    dispersion: .20,
    rimLight: .45,
    specularIntensity: .50,
    shadow: 22,
    cornerRadius: 24,
  );
  static const menu = GlassMaterial(
    blur: 18,
    opacity: .60,
    refraction: .20,
    dispersion: .12,
    rimLight: .34,
    specularIntensity: .38,
    shadow: 12,
    cornerRadius: 14,
  );
  static const card = GlassMaterial(
    blur: 12,
    opacity: .25,
    refraction: .12,
    dispersion: .08,
    rimLight: .25,
    specularIntensity: .30,
    shadow: 4,
    cornerRadius: 16,
  );
  static const readerChrome = GlassMaterial(
    blur: 18,
    opacity: .50,
    refraction: .16,
    dispersion: .10,
    rimLight: .32,
    specularIntensity: .35,
    shadow: 12,
    cornerRadius: 24,
  );
  static const composeChrome = GlassMaterial(
    blur: 18,
    opacity: .50,
    refraction: .16,
    dispersion: .10,
    rimLight: .32,
    specularIntensity: .35,
    shadow: 12,
    cornerRadius: 20,
  );
}
