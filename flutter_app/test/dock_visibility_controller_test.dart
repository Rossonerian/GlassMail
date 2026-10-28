import 'package:flutter_test/flutter_test.dart';
import 'package:glassmail/design/dock_visibility_controller.dart';

void main() {
  test(
    'collapses after sustained downward travel and expands with hysteresis',
    () {
      final controller = DockVisibilityController();
      addTearDown(controller.dispose);

      controller.updateScroll(16, pixels: 120);
      expect(controller.state, DockVisibilityState.expanded);
      controller.updateScroll(11, pixels: 131);
      expect(controller.state, DockVisibilityState.expanded);
      controller.updateScroll(1, pixels: 132);
      expect(controller.state, DockVisibilityState.collapsing);

      controller.updateProgress(.4);
      expect(controller.collapseProgress, .4);
      controller.updateProgress(1);
      expect(controller.state, DockVisibilityState.collapsed);

      controller.updateScroll(-12, pixels: 121);
      expect(controller.state, DockVisibilityState.collapsed);
      controller.updateScroll(-6, pixels: 115);
      expect(controller.state, DockVisibilityState.expanding);
      controller.updateProgress(0);
      expect(controller.state, DockVisibilityState.expanded);
    },
  );

  test('direction changes reset travel and scroll-to-top expands', () {
    final controller = DockVisibilityController()..setCollapsed();
    addTearDown(controller.dispose);

    controller.updateScroll(-10, pixels: 160);
    controller.updateScroll(20, pixels: 180);
    controller.updateScroll(-10, pixels: 170);
    expect(controller.state, DockVisibilityState.collapsed);
    controller.updateScroll(-8, pixels: 162);
    expect(controller.state, DockVisibilityState.expanding);
    controller.updateScroll(-1, pixels: 0);
    expect(controller.state, DockVisibilityState.expanding);
  });
}
