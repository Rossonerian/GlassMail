import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as karmi_glass;

import 'dock_visibility_controller.dart';
import 'glass_mail_glass.dart';

@immutable
class GlassNavDestination {
  const GlassNavDestination(this.label, this.icon, {this.activeIcon});

  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

const defaultGlassNavDestinations = <GlassNavDestination>[
  GlassNavDestination(
    'Inbox',
    Icons.all_inbox_outlined,
    activeIcon: Icons.all_inbox_rounded,
  ),
  GlassNavDestination('Search', Icons.search_rounded),
  GlassNavDestination('Compose', Icons.edit_outlined),
  GlassNavDestination(
    'Sent',
    Icons.send_outlined,
    activeIcon: Icons.send_rounded,
  ),
  GlassNavDestination('More', Icons.more_horiz_rounded),
];

/// Material controls retained by the Glass Lab calibration screen.
///
/// The values are passed to Karmi's liquid-glass renderer for both the bar and
/// its moving selection indicator. The tint follows the active theme.
@immutable
class LiquidGlassNavMaterial {
  const LiquidGlassNavMaterial({
    this.blur = 8,
    this.opacity = .24,
    this.thickness = 26,
    this.refractiveIndex = 1.32,
    this.chromaticAberration = .025,
    this.saturation = 1.22,
    this.ambientStrength = .28,
    this.lightAngle = -.72,
    this.lightIntensity = .78,
  });

  static const production = LiquidGlassNavMaterial();

  final double blur;
  final double opacity;
  final double thickness;
  final double refractiveIndex;
  final double chromaticAberration;
  final double saturation;
  final double ambientStrength;
  final double lightAngle;
  final double lightIntensity;

  karmi_glass.LiquidGlassSettings toSettings(
    Brightness brightness,
    GlassMailTier tier,
  ) {
    final isDark = brightness == Brightness.dark;
    final tint = (isDark ? const Color(0xFF17191E) : const Color(0xFFFFF8EC))
        .withValues(alpha: opacity.clamp(.04, .48));
    final balanced = tier == GlassMailTier.balanced;
    return karmi_glass.LiquidGlassSettings(
      blur: balanced ? blur * .82 : blur,
      glassColor: tint,
      thickness: balanced ? thickness * .84 : thickness,
      refractiveIndex: balanced
          ? 1 + (refractiveIndex - 1) * .82
          : refractiveIndex,
      chromaticAberration: balanced ? 0 : chromaticAberration,
      saturation: saturation,
      ambientStrength: ambientStrength,
      lightAngle: lightAngle,
      lightIntensity: isDark ? lightIntensity : lightIntensity * .84,
    );
  }

  LiquidGlassNavMaterial copyWith({
    double? blur,
    double? opacity,
    double? thickness,
    double? refractiveIndex,
    double? chromaticAberration,
    double? saturation,
    double? ambientStrength,
    double? lightAngle,
    double? lightIntensity,
  }) => LiquidGlassNavMaterial(
    blur: blur ?? this.blur,
    opacity: opacity ?? this.opacity,
    thickness: thickness ?? this.thickness,
    refractiveIndex: refractiveIndex ?? this.refractiveIndex,
    chromaticAberration: chromaticAberration ?? this.chromaticAberration,
    saturation: saturation ?? this.saturation,
    ambientStrength: ambientStrength ?? this.ambientStrength,
    lightAngle: lightAngle ?? this.lightAngle,
    lightIntensity: lightIntensity ?? this.lightIntensity,
  );
}

/// GlassMail's navigation adapter around Karmi's real draggable glass bar.
///
/// `GlassTabBar.minimizable` uses the same drag-driven indicator as
/// `GlassTabBar.bottom`, while also allowing the existing scroll controller to
/// minimize the bar. That keeps pointer tracking and tab snapping inside the
/// package rather than recreating them in GlassMail.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.selected,
    required this.visibilityController,
    this.destinations = defaultGlassNavDestinations,
    this.onDestinationSelected,
    this.onQuickSearch,
    this.material = LiquidGlassNavMaterial.production,
  });

  final String selected;
  final DockVisibilityController visibilityController;
  final List<GlassNavDestination> destinations;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onQuickSearch;
  final LiquidGlassNavMaterial material;

  List<GlassNavDestination> get _destinations =>
      destinations.isEmpty ? defaultGlassNavDestinations : destinations;

  int get _selectedIndex {
    final index = _destinations.indexWhere((item) => item.label == selected);
    return index < 0 ? 0 : index;
  }

  void _select(int index) {
    final destination = _destinations[index];
    if (destination.label == 'Search' && destination.label == selected) {
      onQuickSearch?.call();
      return;
    }
    onDestinationSelected?.call(destination.label);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final reduceTransparency =
        MailGlassAccessibility.reduceTransparencyOf(context) ||
        mediaQuery.highContrast;
    final tier = MailGlassAccessibility.tierOf(context);
    final useOpaqueNavigation = reduceTransparency || tier == GlassMailTier.off;
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: AnimatedBuilder(
          animation: visibilityController,
          builder: (context, _) {
            if (useOpaqueNavigation) {
              return NavigationBar(
                height: mailDockContentHeight(context),
                selectedIndex: _selectedIndex,
                onDestinationSelected: _select,
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(
                        destination.activeIcon ?? destination.icon,
                      ),
                      label: destination.label,
                      tooltip: destination.label,
                    ),
                ],
              );
            }

            final quality = switch (tier) {
              GlassMailTier.full => karmi_glass.GlassQuality.premium,
              GlassMailTier.balanced => karmi_glass.GlassQuality.standard,
              GlassMailTier.lite => karmi_glass.GlassQuality.minimal,
              GlassMailTier.off => karmi_glass.GlassQuality.minimal,
            };
            final settings = material.toSettings(theme.brightness, tier);
            final reduceMotion = mediaQuery.disableAnimations;

            return karmi_glass.GlassTabBar.minimizable(
              minimized: visibilityController.isCollapsed,
              onMinimizedTabTap: visibilityController.setExpanded,
              selectedIndex: _selectedIndex,
              onTabSelected: _select,
              tabs: [
                for (final destination in _destinations)
                  karmi_glass.GlassTab(
                    icon: Icon(destination.icon),
                    activeIcon: Icon(
                      destination.activeIcon ?? destination.icon,
                    ),
                    label: destination.label,
                    semanticLabel: destination.label,
                  ),
              ],
              barHeight: 64,
              minimizedBarHeight: 50,
              settings: settings,
              indicatorSettings: settings,
              quality: quality,
              backgroundQuality: quality,
              interactionBehavior: reduceMotion
                  ? karmi_glass.GlassInteractionBehavior.none
                  : karmi_glass.GlassInteractionBehavior.full,
              pressScale: 1.035,
              selectedIconColor: theme.colorScheme.primary,
              selectedLabelColor: theme.colorScheme.primary,
              unselectedIconColor: theme.colorScheme.onSurfaceVariant,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            );
          },
        ),
      ),
    );
  }
}

/// Expanded bar height including Karmi's vertical glass padding.
double mailDockContentHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return math.max(90.0, math.min(124.0, 64 + 40 * scale));
}

double mailDockTotalHeight(BuildContext context) =>
    mailDockContentHeight(context) + MediaQuery.viewPaddingOf(context).bottom;
