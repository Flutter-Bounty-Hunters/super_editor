```dart
import 'package:flutter/material.dart';

class IosSystemContextMenu {
  final OverlayEntry _overlayEntry;

  IosSystemContextMenu(this._overlayEntry);

  bool get isVisible => _overlayEntry.mounted;

  void show() {
    if (!isVisible) {
      _overlayEntry.insert();
    }
  }

  void hide() {
    if (isVisible) {
      _overlayEntry.remove();
    }
  }
}
```
