import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../design/glass_mail_glass.dart';
import '../../design/glass_material.dart';

class GlassLabScreen extends StatefulWidget {
  const GlassLabScreen({super.key});

  @override
  State<GlassLabScreen> createState() => _GlassLabScreenState();
}

class _GlassLabScreenState extends State<GlassLabScreen> {
  GlassMailTier _tier = GlassMailTier.balanced;
  GlassMaterial _material = GlassPresets.navigation;
  bool _showGlass = true;
  bool _reduceTransparency = false;
  int _sampleCount = 0;
  double _meanRasterMs = 0;
  double _peakRasterMs = 0;
  DateTime _lastPublished = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_recordTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_recordTimings);
    super.dispose();
  }

  void _recordTimings(List<ui.FrameTiming> timings) {
    if (timings.isEmpty || !mounted) return;
    var totalMicros = _meanRasterMs * _sampleCount * 1000;
    var peakMicros = _peakRasterMs * 1000;
    for (final timing in timings) {
      final raster = timing.rasterDuration.inMicroseconds.toDouble();
      totalMicros += raster;
      peakMicros = raster > peakMicros ? raster : peakMicros;
      _sampleCount++;
    }
    _meanRasterMs = totalMicros / _sampleCount / 1000;
    _peakRasterMs = peakMicros / 1000;
    final now = DateTime.now();
    if (now.difference(_lastPublished).inMilliseconds < 500) return;
    _lastPublished = now;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final names = <String, GlassMaterial>{
      'Navigation': GlassPresets.navigation,
      'Toolbar': GlassPresets.toolbar,
      'Search': GlassPresets.search,
      'Floating action': GlassPresets.floatingAction,
      'Bottom bar': GlassPresets.bottomBar,
      'Sheet': GlassPresets.sheet,
      'Dialog': GlassPresets.dialog,
      'Menu': GlassPresets.menu,
      'Card': GlassPresets.card,
      'Reader chrome': GlassPresets.readerChrome,
      'Compose chrome': GlassPresets.composeChrome,
    };
    final selectedName = names.entries
        .firstWhere(
          (entry) => identical(entry.value, _material),
          orElse: () => names.entries.first,
        )
        .key;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Glass Lab'),
        leading: IconButton(
          tooltip: 'Back to Inbox',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Raster · $_sampleCount frames',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_meanRasterMs.toStringAsFixed(2)} ms avg'),
                    Text('${_peakRasterMs.toStringAsFixed(2)} ms peak'),
                  ],
                ),
                IconButton(
                  tooltip: 'Reset frame sample',
                  onPressed: () => setState(() {
                    _sampleCount = 0;
                    _meanRasterMs = 0;
                    _peakRasterMs = 0;
                    _lastPublished = DateTime.fromMillisecondsSinceEpoch(0);
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          Text(
            'A small, bounded glass preview',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'Scroll the colors behind the surface and compare the app-owned fallback.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFC9D5B0),
                  Color(0xFFF0D5B8),
                  Color(0xFFA6B9C6),
                ],
              ),
            ),
            child: SizedBox(
              height: 214,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BackdropSamplePainter()),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: _showGlass
                        ? GlassMailGlass(
                            material: _material,
                            tier: _tier,
                            reduceTransparency: _reduceTransparency,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 18,
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 26),
                                SizedBox(height: 8),
                                Text(
                                  'GlassMail chrome',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text('Foreground stays crisp'),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                _material.cornerRadius,
                              ),
                              color: colors.surface,
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 26),
                                SizedBox(height: 8),
                                Text(
                                  'Opaque comparison',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text('Glass effect is paused'),
                              ],
                            ),
                          ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(_showGlass ? 'GLASS ON' : 'GLASS OFF'),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Text(
                      'BACKDROP SAMPLE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show glass preview'),
                    value: _showGlass,
                    onChanged: (value) => setState(() => _showGlass = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce transparency'),
                    subtitle: const Text(
                      'Use the opaque, high-contrast fallback',
                    ),
                    value: _reduceTransparency,
                    onChanged: (value) =>
                        setState(() => _reduceTransparency = value),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Material preset'),
                    trailing: DropdownButton<String>(
                      value: selectedName,
                      items: [
                        for (final name in names.keys)
                          DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: (name) {
                        if (name != null) {
                          setState(() => _material = names[name]!);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Renderer tier'),
                    subtitle: Text(_tier.name.toUpperCase()),
                    trailing: DropdownButton<GlassMailTier>(
                      value: _tier,
                      items: const [
                        DropdownMenuItem(
                          value: GlassMailTier.full,
                          child: Text('FULL'),
                        ),
                        DropdownMenuItem(
                          value: GlassMailTier.balanced,
                          child: Text('BALANCED'),
                        ),
                        DropdownMenuItem(
                          value: GlassMailTier.light,
                          child: Text('LIGHT'),
                        ),
                        DropdownMenuItem(
                          value: GlassMailTier.off,
                          child: Text('OFF'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _tier = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Backdrop samples',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final sample in _samples)
            Container(
              height: 56,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: sample.$1,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                sample.$2,
                style: TextStyle(color: sample.$3, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

const _samples = <(Color, String, Color)>[
  (
    Color(0xFFE9D0AE),
    'Warm sand · body text remains opaque',
    Color(0xFF33271A),
  ),
  (Color(0xFF8A9C78), 'Sage green · soft tint sample', Color(0xFFFFFFFF)),
  (
    Color(0xFFC6D3DB),
    'Morning blue · highlights stay sharp',
    Color(0xFF1F2A31),
  ),
  (Color(0xFFB68D6F), 'Terracotta · simple color field', Color(0xFFFFFFFF)),
  (Color(0xFF413525), 'Dark olive · contrast sample', Color(0xFFF6F3EE)),
];

class _BackdropSamplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final circles = <(Offset, double, Color)>[
      (
        Offset(size.width * .18, size.height * .72),
        52,
        const Color(0xFF657A59),
      ),
      (
        Offset(size.width * .79, size.height * .28),
        64,
        const Color(0xFFC18C65),
      ),
      (
        Offset(size.width * .82, size.height * .82),
        34,
        const Color(0xFF52677A),
      ),
      (
        Offset(size.width * .26, size.height * .22),
        23,
        const Color(0xFFFFF1D6),
      ),
    ];
    for (final (center, radius, color) in circles) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: .55),
      );
    }
    final line = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 2;
    for (var i = 0; i < 9; i++) {
      final y = size.height * .12 + i * 20.0;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y + 24), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
