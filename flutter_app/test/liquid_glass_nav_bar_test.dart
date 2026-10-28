import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail/design/dock_visibility_controller.dart';
import 'package:glassmail/design/glass_mail_glass.dart';
import 'package:glassmail/design/liquid_glass_nav_bar.dart';
import 'package:glassmail/features/glass_lab/liquid_glass_nav_calibration_screen.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

void main() {
  testWidgets('expanded destinations are accessible and invoke callbacks', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);
    final selectedDestinations = <String>[];
    var quickSearchCount = 0;

    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: 'Inbox',
        onSelected: selectedDestinations.add,
        onQuickSearch: () => quickSearchCount++,
      ),
    );

    expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);
    expect(find.byType(LiquidGlassLayer), findsOneWidget);
    // The platter and the selected optical inset are two shapes inside the
    // same bounded renderer layer, rather than independent glass engines.
    expect(find.byType(LiquidGlass), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('mail-dock-selected-optic')),
      findsOneWidget,
    );
    expect(find.byType(GlassGlow), findsOneWidget);
    for (final destination in ['Inbox', 'Search', 'Compose', 'Sent', 'More']) {
      expect(find.bySemanticsLabel(destination), findsOneWidget);
      expect(
        tester.getSize(find.bySemanticsLabel(destination)).height,
        greaterThanOrEqualTo(48),
      );
    }

    await tester.tap(find.bySemanticsLabel('Search'));
    expect(selectedDestinations, ['Search']);

    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: 'Search',
        onSelected: selectedDestinations.add,
        onQuickSearch: () => quickSearchCount++,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Search'));
    expect(quickSearchCount, 1);

    await tester.tap(find.bySemanticsLabel('Compose'));
    await tester.tap(find.bySemanticsLabel('Sent'));
    await tester.tap(find.bySemanticsLabel('More'));
    expect(selectedDestinations, ['Search', 'Compose', 'Sent', 'More']);
  });

  testWidgets('collapsed selected item expands without blocking navigation', (
    tester,
  ) async {
    final visibility = DockVisibilityController()..setCollapsed();
    addTearDown(visibility.dispose);
    final selectedDestinations = <String>[];

    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: 'Inbox',
        onSelected: selectedDestinations.add,
      ),
    );
    expect(find.byKey(const ValueKey('mail-dock-compact')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Inbox'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);
    expect(selectedDestinations, isEmpty);
  });

  testWidgets('selected optical inset animates with the active destination', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      _dockApp(visibility: visibility, selected: 'Inbox', onSelected: (_) {}),
    );
    final optic = find.byKey(const ValueKey('mail-dock-selected-optic'));
    final inboxCenter = tester.getRect(optic).center.dx;
    expect(
      inboxCenter,
      closeTo(tester.getRect(find.bySemanticsLabel('Inbox')).center.dx, 1),
    );

    await tester.pumpWidget(
      _dockApp(visibility: visibility, selected: 'Search', onSelected: (_) {}),
    );
    await tester.pumpAndSettle();

    final searchCenter = tester.getRect(optic).center.dx;
    expect(searchCenter, greaterThan(inboxCenter + 40));
    expect(
      searchCenter,
      closeTo(tester.getRect(find.bySemanticsLabel('Search')).center.dx, 1),
    );
  });

  testWidgets('scroll content passes behind a stable glass layer', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      _dockApp(visibility: visibility, selected: 'Inbox', onSelected: (_) {}),
    );
    final layerSize = tester.getSize(
      find.byKey(const ValueKey('mail-dock-glass-layer')),
    );
    final bodyBounds = tester.getRect(find.byType(ListView));
    final dockBounds = tester.getRect(
      find.byKey(const ValueKey('mail-dock-bottom-inset')),
    );
    expect(bodyBounds.bottom, greaterThanOrEqualTo(dockBounds.top));

    visibility.updateScroll(80, pixels: 120);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-dock-compact')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('mail-dock-glass-layer'))),
      layerSize,
    );

    visibility.updateScroll(-50, pixels: 70);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('mail-dock-glass-layer'))),
      layerSize,
    );
  });

  testWidgets('short finger scrolls collapse and re-expand the dock', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      _dockApp(visibility: visibility, selected: 'Inbox', onSelected: (_) {}),
    );

    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -36));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-dock-compact')), findsOneWidget);

    await tester.drag(list, const Offset(0, 24));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);
  });

  testWidgets('hold, move, release remains responsive across repeated use', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      _dockApp(visibility: visibility, selected: 'Inbox', onSelected: (_) {}),
    );
    final dock = tester.getRect(
      find.byKey(const ValueKey('mail-dock-expanded')),
    );
    final stretch = tester.widget<LiquidStretch>(find.byType(LiquidStretch));
    expect(stretch.interactionScale, greaterThanOrEqualTo(1.03));
    expect(stretch.stretch, greaterThanOrEqualTo(.6));
    for (var index = 0; index < 20; index++) {
      final gesture = await tester.startGesture(dock.center);
      await gesture.moveBy(const Offset(18, -8));
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.moveBy(const Offset(-10, 14));
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 360));
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mail-dock-expanded')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass selection follows drag and commits only on release', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);
    final selectedDestinations = <String>[];
    var selected = 'Inbox';

    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: selected,
        onSelected: (destination) {
          selectedDestinations.add(destination);
          selected = destination;
        },
      ),
    );
    final sent = tester.getRect(find.bySemanticsLabel('Sent'));
    final optic = find.byKey(const ValueKey('mail-dock-selected-optic'));
    final gesture = await tester.startGesture(tester.getRect(optic).center);
    await gesture.moveTo(sent.center);
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.getRect(optic).center.dx, closeTo(sent.center.dx, 1));
    expect(selectedDestinations, isEmpty);

    await gesture.up();
    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: selected,
        onSelected: (destination) {
          selectedDestinations.add(destination);
          selected = destination;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(selectedDestinations, ['Sent']);
    expect(tester.getRect(optic).center.dx, closeTo(sent.center.dx, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled glass drag returns to the selected destination', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);
    final selectedDestinations = <String>[];

    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: 'Inbox',
        onSelected: selectedDestinations.add,
      ),
    );
    final optic = find.byKey(const ValueKey('mail-dock-selected-optic'));
    final inbox = tester.getRect(find.bySemanticsLabel('Inbox'));
    final sent = tester.getRect(find.bySemanticsLabel('Sent'));
    final gesture = await tester.startGesture(tester.getRect(optic).center);
    await gesture.moveTo(sent.center);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(optic).center.dx, closeTo(sent.center.dx, 1));
    expect(selectedDestinations, isEmpty);

    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(selectedDestinations, isEmpty);
    expect(tester.getRect(optic).center.dx, closeTo(inbox.center.dx, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce transparency and high contrast use an opaque fallback', (
    tester,
  ) async {
    final visibility = DockVisibilityController();
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: 'Inbox',
        onSelected: (_) {},
        reduceTransparency: true,
      ),
    );
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.byType(LiquidGlassLayer), findsNothing);

    await tester.pumpWidget(
      _dockApp(
        visibility: visibility,
        selected: 'Inbox',
        onSelected: (_) {},
        highContrast: true,
      ),
    );
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.byType(LiquidGlassLayer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion changes state without stretch or morph animation',
    (tester) async {
      final visibility = DockVisibilityController();
      addTearDown(visibility.dispose);

      await tester.pumpWidget(
        _dockApp(
          visibility: visibility,
          selected: 'Inbox',
          onSelected: (_) {},
          disableAnimations: true,
        ),
      );
      expect(find.byType(LiquidStretch), findsNothing);
      expect(find.byType(GlassGlow), findsNothing);

      visibility.updateScroll(80, pixels: 80);
      await tester.pump();
      expect(find.byKey(const ValueKey('mail-dock-compact')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('navigation profile maps into pinned renderer settings', () {
    const material = LiquidGlassNavMaterial.production;
    final dark = material.toSettings(Brightness.dark, GlassMailTier.full);
    expect(dark.blur, 8);
    expect(dark.thickness, 26);
    expect(dark.refractiveIndex, 1.32);
    expect(dark.chromaticAberration, .025);
    expect(dark.glassColor.a, .24);

    final balanced = material.toSettings(
      Brightness.light,
      GlassMailTier.balanced,
    );
    expect(balanced.blur, closeTo(6.56, .001));
    expect(balanced.chromaticAberration, 0);
    expect(balanced.glassColor.a, .24);
  });

  testWidgets('debug calibration exposes material controls over mail content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MailGlassAccessibility(
        glassTier: GlassMailTier.full,
        reduceTransparency: false,
        child: const MaterialApp(home: LiquidGlassNavCalibrationScreen()),
      ),
    );

    expect(find.text('Navbar calibration'), findsOneWidget);
    expect(find.bySemanticsLabel('Sent'), findsOneWidget);
    expect(find.text('Use full renderer tier'), findsOneWidget);
    expect(find.text('Blur'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Refraction'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Refraction'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Scrolling mail rows'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Scrolling mail rows'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _dockApp({
  required DockVisibilityController visibility,
  required String selected,
  required ValueChanged<String> onSelected,
  VoidCallback? onQuickSearch,
  bool reduceTransparency = false,
  bool disableAnimations = false,
  bool highContrast = false,
}) {
  return MailGlassAccessibility(
    glassTier: GlassMailTier.full,
    reduceTransparency: reduceTransparency,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          highContrast: highContrast,
        ),
        child: child!,
      ),
      home: Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: visibility.handleScrollNotification,
          child: ListView.builder(
            itemCount: 40,
            itemBuilder: (_, index) => ListTile(title: Text('Mail $index')),
          ),
        ),
        bottomNavigationBar: LiquidGlassNavBar(
          selected: selected,
          visibilityController: visibility,
          onDestinationSelected: onSelected,
          onQuickSearch: onQuickSearch,
        ),
      ),
    ),
  );
}
