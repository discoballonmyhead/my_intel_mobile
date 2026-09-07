import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Publishes the current screen shape to the whole tree.
///
/// Widgets read `context.watch<ResponsiveProvider>()` instead of calling
/// MediaQuery themselves, which keeps layout decisions testable — a test can
/// push a synthetic size without pumping a real window.
class ResponsiveProvider extends ChangeNotifier {
  ResponsiveProvider({Size initialSize = Size.zero})
      : _size = initialSize,
        _orientation = initialSize.width > initialSize.height
            ? Orientation.landscape
            : Orientation.portrait;

  Size _size;
  Orientation _orientation;
  EdgeInsets _viewPadding = EdgeInsets.zero;
  double _textScale = 1;

  Size get size => _size;
  double get width => _size.width;
  double get height => _size.height;
  Orientation get orientation => _orientation;
  EdgeInsets get viewPadding => _viewPadding;
  double get textScale => _textScale;

  DeviceType get deviceType => Breakpoints.fromWidth(_size.width);

  /// True for phones — the app's primary target.
  bool get isMobile => _size.width < Breakpoints.mobile;
  bool get isCompact => deviceType == DeviceType.compact;
  bool get isMedium => deviceType == DeviceType.medium;
  bool get isExpanded => deviceType == DeviceType.expanded;

  /// Bottom nav on phones, side rail once there is room for it.
  bool get useBottomNav => isMobile;
  bool get useNavRail => !isMobile;

  /// Phones get a single column; wider screens centre a readable column.
  int get feedColumns => isExpanded ? 2 : 1;

  double get horizontalGutter => switch (deviceType) {
        DeviceType.compact => 16,
        DeviceType.medium => 24,
        DeviceType.expanded => 32,
      };

  /// Scales a value between the compact and expanded ends of the scale.
  T value<T>({required T compact, T? medium, T? expanded}) {
    return switch (deviceType) {
      DeviceType.compact => compact,
      DeviceType.medium => medium ?? compact,
      DeviceType.expanded => expanded ?? medium ?? compact,
    };
  }

  /// Called once per frame from [ResponsiveScope]; only notifies on change.
  void update(MediaQueryData media) {
    final nextOrientation = media.orientation;
    if (_size == media.size &&
        _orientation == nextOrientation &&
        _viewPadding == media.viewPadding &&
        _textScale == media.textScaler.scale(1)) {
      return;
    }
    _size = media.size;
    _orientation = nextOrientation;
    _viewPadding = media.viewPadding;
    _textScale = media.textScaler.scale(1);
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}
