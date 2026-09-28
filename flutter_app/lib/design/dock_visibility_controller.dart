import 'package:flutter/material.dart';

enum DockVisibilityState { expanded, collapsing, collapsed, expanding }

/// Keeps the bottom dock stable while applying scroll-aware collapse with
/// separate thresholds for collapsing and expanding.
class DockVisibilityController extends ChangeNotifier {
  static const _collapseThreshold = 28.0;
  static const _expandThreshold = 18.0;

  DockVisibilityState _state = DockVisibilityState.expanded;
  double _collapseProgress = 0;
  double _scrollTravel = 0;
  int _scrollDirection = 0;

  DockVisibilityState get state => _state;
  double get collapseProgress => _collapseProgress;
  int get scrollDirection => _scrollDirection;
  double get scrollTravel => _scrollTravel;
  bool get isCollapsed =>
      _collapseProgress >= .5 ||
      _state == DockVisibilityState.collapsing ||
      _state == DockVisibilityState.collapsed;

  void setExpanded() {
    _scrollTravel = 0;
    _scrollDirection = 0;
    if (_state == DockVisibilityState.expanded && _collapseProgress == 0) {
      return;
    }
    _state = _collapseProgress > 0
        ? DockVisibilityState.expanding
        : DockVisibilityState.expanded;
    notifyListeners();
  }

  void setCollapsed() {
    _scrollTravel = 0;
    _scrollDirection = 0;
    if (_state == DockVisibilityState.collapsed && _collapseProgress == 1) {
      return;
    }
    _state = DockVisibilityState.collapsed;
    _collapseProgress = 1;
    notifyListeners();
  }

  void resetScrollTravel() {
    _scrollTravel = 0;
    _scrollDirection = 0;
  }

  /// Routes real vertical scroll notifications into the dock state machine.
  /// Keep ballistic updates too: a short finger drag can continue as a fling
  /// after the pointer is lifted, and that remaining travel must still count.
  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      resetScrollTravel();
    } else if (notification is ScrollUpdateNotification &&
        notification.metrics.axis == Axis.vertical) {
      updateScroll(
        notification.scrollDelta ?? 0,
        pixels: notification.metrics.pixels,
      );
    }
    return false;
  }

  /// Applies scroll deltas. Reversals reset accumulated travel, so a short
  /// jitter cannot toggle the dock. Low thresholds let ordinary touch scrolls
  /// collapse the dock without requiring a long fling.
  void updateScroll(double delta, {double? pixels}) {
    if (pixels != null && pixels <= 0) {
      setExpanded();
      return;
    }
    if (delta == 0 || !delta.isFinite) return;

    final direction = delta.sign.toInt();
    if (direction != _scrollDirection) {
      _scrollDirection = direction;
      _scrollTravel = 0;
    }
    _scrollTravel += delta.abs();

    final movingTowardCollapsed =
        _state == DockVisibilityState.collapsing ||
        _state == DockVisibilityState.collapsed;
    if (!movingTowardCollapsed &&
        direction > 0 &&
        _scrollTravel >= _collapseThreshold) {
      _state = DockVisibilityState.collapsing;
      _scrollTravel = 0;
      notifyListeners();
    } else if (movingTowardCollapsed &&
        direction < 0 &&
        _scrollTravel >= _expandThreshold) {
      _state = DockVisibilityState.expanding;
      _scrollTravel = 0;
      notifyListeners();
    }
  }

  /// Receives the navbar animation value so debug/accessibility state reflects
  /// the actual visible transition rather than only its target.
  void updateProgress(double progress) {
    final value = progress.clamp(0.0, 1.0).toDouble();
    if ((_collapseProgress - value).abs() < .001) return;
    _collapseProgress = value;

    if (value == 0 && _state == DockVisibilityState.expanding) {
      _state = DockVisibilityState.expanded;
    } else if (value == 1 && _state == DockVisibilityState.collapsing) {
      _state = DockVisibilityState.collapsed;
    }
    notifyListeners();
  }
}
