import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/dock_visibility_controller.dart';
import '../../design/glass_mail_glass.dart';
import '../../design/glass_mail_theme.dart';
import '../../design/liquid_glass_nav_bar.dart';

enum _BackdropMode { mixed, light, dark }

/// Debug-only scene for tuning the real mail navigation material against
/// moving, high-contrast mail-like content.
class LiquidGlassNavCalibrationScreen extends StatefulWidget {
  const LiquidGlassNavCalibrationScreen({super.key});

  @override
  State<LiquidGlassNavCalibrationScreen> createState() =>
      _LiquidGlassNavCalibrationScreenState();
}

class _LiquidGlassNavCalibrationScreenState
    extends State<LiquidGlassNavCalibrationScreen> {
  final _visibility = DockVisibilityController();
  LiquidGlassNavMaterial _material = LiquidGlassNavMaterial.production;
  _BackdropMode _backdrop = _BackdropMode.mixed;
  String _selected = 'Inbox';
  bool _fullRenderer = true;
  bool _darkTheme = false;

  @override
  void dispose() {
    _visibility.dispose();
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return;
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _visibility.resetScrollTravel();
    } else if (notification is ScrollUpdateNotification) {
      _visibility.updateScroll(
        notification.scrollDelta ?? 0,
        pixels: notification.metrics.pixels,
      );
    }
  }

  void _updateMaterial(LiquidGlassNavMaterial Function() update) {
    setState(() => _material = update());
  }

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode, 'The glass navbar calibration screen is debug-only.');
    final colors = glassMailTheme(
      _darkTheme ? Brightness.dark : Brightness.light,
    ).colorScheme;
    final activeTier = MailGlassAccessibility.tierOf(context);
    final reduceTransparency = MailGlassAccessibility.reduceTransparencyOf(
      context,
    );
    final scene = _backdrop;

    return Theme(
      data: glassMailTheme(_darkTheme ? Brightness.dark : Brightness.light),
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('Navbar calibration'),
          leading: IconButton(
            tooltip: 'Back to Glass Lab',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onScroll(notification);
            return false;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              mailDockTotalHeight(context) + 24,
            ),
            children: [
              Text(
                'Tune the production navbar material',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Hold the selected glass pill and drag it across tabs; the indicator follows your finger and snaps to the tab when released. Scroll the message rows to minimize and restore the bar.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_BackdropMode>(
                segments: const [
                  ButtonSegment(
                    value: _BackdropMode.mixed,
                    label: Text('Mixed'),
                  ),
                  ButtonSegment(
                    value: _BackdropMode.light,
                    label: Text('Light'),
                  ),
                  ButtonSegment(value: _BackdropMode.dark, label: Text('Dark')),
                ],
                selected: {_backdrop},
                onSelectionChanged: (values) => setState(() {
                  _backdrop = values.first;
                }),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark app theme'),
                      value: _darkTheme,
                      onChanged: (value) => setState(() => _darkTheme = value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Use full renderer tier'),
                      subtitle: const Text(
                        'Expose refraction and chromatic tuning in this debug scene',
                      ),
                      value: _fullRenderer,
                      onChanged: (value) =>
                          setState(() => _fullRenderer = value),
                    ),
                    const Divider(height: 1),
                    _slider(
                      'Blur',
                      _material.blur,
                      0,
                      20,
                      (value) => _updateMaterial(
                        () => _material.copyWith(blur: value),
                      ),
                      suffix: 'px',
                    ),
                    _slider(
                      'Tint opacity',
                      _material.opacity,
                      .04,
                      .48,
                      (value) => _updateMaterial(
                        () => _material.copyWith(opacity: value),
                      ),
                    ),
                    _slider(
                      'Thickness',
                      _material.thickness,
                      0,
                      60,
                      (value) => _updateMaterial(
                        () => _material.copyWith(thickness: value),
                      ),
                      suffix: 'px',
                    ),
                    _slider(
                      'Refraction',
                      _material.refractiveIndex,
                      1,
                      1.6,
                      (value) => _updateMaterial(
                        () => _material.copyWith(refractiveIndex: value),
                      ),
                    ),
                    _slider(
                      'Chromatic aberration',
                      _material.chromaticAberration,
                      0,
                      .12,
                      (value) => _updateMaterial(
                        () => _material.copyWith(chromaticAberration: value),
                      ),
                    ),
                    _slider(
                      'Light intensity',
                      _material.lightIntensity,
                      0,
                      1.5,
                      (value) => _updateMaterial(
                        () => _material.copyWith(lightIntensity: value),
                      ),
                    ),
                    _slider(
                      'Ambient strength',
                      _material.ambientStrength,
                      0,
                      1,
                      (value) => _updateMaterial(
                        () => _material.copyWith(ambientStrength: value),
                      ),
                    ),
                    _slider(
                      'Saturation',
                      _material.saturation,
                      0,
                      2,
                      (value) => _updateMaterial(
                        () => _material.copyWith(saturation: value),
                      ),
                    ),
                    ListTile(
                      title: const Text('Selected destination'),
                      trailing: DropdownButton<String>(
                        value: _selected,
                        items: const [
                          DropdownMenuItem(
                            value: 'Inbox',
                            child: Text('Inbox'),
                          ),
                          DropdownMenuItem(
                            value: 'Search',
                            child: Text('Search'),
                          ),
                          DropdownMenuItem(
                            value: 'Compose',
                            child: Text('Compose'),
                          ),
                          DropdownMenuItem(value: 'Sent', child: Text('Sent')),
                          DropdownMenuItem(value: 'More', child: Text('More')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _selected = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _backdropSample(scene),
              const SizedBox(height: 14),
              Text(
                'Scrolling mail rows',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              for (var index = 0; index < 18; index++)
                _messageRow(context, scene, index),
            ],
          ),
        ),
        bottomNavigationBar: MailGlassAccessibility(
          glassTier: _fullRenderer ? GlassMailTier.full : activeTier,
          reduceTransparency: reduceTransparency,
          child: LiquidGlassNavBar(
            selected: _selected,
            visibilityController: _visibility,
            material: _material,
            onDestinationSelected: (destination) =>
                setState(() => _selected = destination),
            onQuickSearch: () => setState(() => _selected = 'Search'),
          ),
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String suffix = '',
  }) {
    final displayed = value < .1
        ? value.toStringAsFixed(3)
        : value.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('$displayed$suffix'),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _backdropSample(_BackdropMode mode) {
    return Container(
      height: 144,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: mode == _BackdropMode.dark
              ? const [Color(0xFF11141B), Color(0xFF52443A), Color(0xFF172E3A)]
              : mode == _BackdropMode.light
              ? const [Color(0xFFFFE9BF), Color(0xFFC4D8E4), Color(0xFFF3E3D6)]
              : const [Color(0xFFFAE6C4), Color(0xFF26313B), Color(0xFFD8BD72)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 22,
            top: 22,
            child: _avatar('A', const Color(0xFFB06E50)),
          ),
          Positioned(
            right: 42,
            top: 26,
            child: _avatar('K', const Color(0xFF547D96)),
          ),
          Positioned(
            left: 80,
            bottom: 28,
            child: _avatar('M', const Color(0xFF7B8955)),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              'BRIGHT  ·  DARK  ·  MIXED',
              style: TextStyle(
                color: mode == _BackdropMode.light
                    ? const Color(0xFF1B232B)
                    : Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageRow(BuildContext context, _BackdropMode mode, int index) {
    const senders = [
      'Avery Chen',
      'The Design Weekly',
      'Mina Patel',
      'Northstar Travel',
      'Jon Bell',
      'Studio Updates',
    ];
    const subjects = [
      'The latest draft is ready',
      'A few ideas for the next release',
      'Can we review this together?',
      'Your itinerary has changed',
      'Notes from this morning',
      'New work is waiting for you',
    ];
    const snippets = [
      'I added the updated mockups and marked the places that need a second look.',
      'This week: color, type, and the details that make interfaces feel calm.',
      'I can move the meeting if another time works better for everyone.',
      'There is one new detail for the outbound trip. Open to see the update.',
      'Sharing the decisions and follow-ups while everything is fresh.',
      'Take a look when you have a moment. The preview includes the full context.',
    ];
    final palette = switch (mode) {
      _BackdropMode.light => (
        const Color(0xFFFFF7E9),
        const Color(0xFF28231E),
        const Color(0xFF665C52),
      ),
      _BackdropMode.dark => (
        const Color(0xFF17202A),
        const Color(0xFFF3F5F7),
        const Color(0xFFB7C2CC),
      ),
      _BackdropMode.mixed => switch (index % 4) {
        0 => (
          const Color(0xFFFFF1C9),
          const Color(0xFF252018),
          const Color(0xFF594D3D),
        ),
        1 => (
          const Color(0xFF182733),
          const Color(0xFFF4F6F8),
          const Color(0xFFBDC8D0),
        ),
        2 => (
          const Color(0xFFCA8E52),
          const Color(0xFF201A15),
          const Color(0xFF3A2C20),
        ),
        _ => (
          const Color(0xFFE5EBF0),
          const Color(0xFF19242D),
          const Color(0xFF465761),
        ),
      },
    };
    final item = index % senders.length;
    final avatarColors = [
      const Color(0xFF7E665E),
      const Color(0xFF356A80),
      const Color(0xFF6C7B4B),
      const Color(0xFFB06F49),
      const Color(0xFF5C5279),
      const Color(0xFF3E786B),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.$1),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 3,
            ),
            leading: _avatar(senders[item][0], avatarColors[item]),
            title: Text(
              senders[item],
              style: TextStyle(color: palette.$2, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjects[item],
                    style: TextStyle(
                      color: palette.$2,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    snippets[item],
                    style: TextStyle(color: palette.$3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing: Text(
              '${8 + index % 4}:${(index * 7) % 60}'.padRight(5, '0'),
              style: TextStyle(color: palette.$3, fontSize: 11),
            ),
          ),
          Divider(
            height: 1,
            indent: 70,
            color: palette.$3.withValues(alpha: .35),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String initial, Color color) => CircleAvatar(
    radius: 21,
    backgroundColor: color,
    child: Text(
      initial,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}
