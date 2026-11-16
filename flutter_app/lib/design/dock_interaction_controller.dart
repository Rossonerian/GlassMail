import 'package:flutter/material.dart';

class DockInteractionController extends ChangeNotifier {
  bool _isActive = false;
  Offset _pointerPosition = Offset.zero;
  Offset _displacement = Offset.zero;
  Offset _initialPosition = Offset.zero;

  bool get isActive => _isActive;
  Offset get pointerPosition => _pointerPosition;
  Offset get displacement => _displacement;

  void pointerDown(PointerDownEvent event) {
    _isActive = true;
    _pointerPosition = event.localPosition;
    _initialPosition = event.localPosition;
    _displacement = Offset.zero;
    notifyListeners();
  }

  void pointerMove(PointerMoveEvent event) {
    if (_isActive) {
      _pointerPosition = event.localPosition;
      // Keep translation restrained; LiquidStretch supplies the stronger
      // material deformation while this value drives a small whole-dock drift.
      final delta = _pointerPosition - _initialPosition;
      _displacement = Offset(
        (delta.dx * 0.12).clamp(-12.0, 12.0).toDouble(),
        (delta.dy * 0.12).clamp(-12.0, 12.0).toDouble(),
      );
      notifyListeners();
    }
  }

  void pointerUp(PointerUpEvent event) {
    _isActive = false;
    _displacement = Offset.zero;
    notifyListeners();
  }

  void pointerCancel(PointerCancelEvent event) {
    _isActive = false;
    _displacement = Offset.zero;
    notifyListeners();
  }
}
