/// Breakpoints carried over from the web client's media queries — the phone
/// cut-off stays at 768px so both clients agree on what "mobile" means.
enum DeviceType { compact, medium, expanded }

class Breakpoints {
  const Breakpoints._();

  /// < 600  — phones in portrait
  static const double compact = 600;

  /// 600–1024 — large phones in landscape, small tablets
  static const double medium = 1024;

  /// The web client's `@media (max-width: 768px)` threshold.
  static const double mobile = 768;

  static DeviceType fromWidth(double width) {
    if (width < compact) return DeviceType.compact;
    if (width < medium) return DeviceType.medium;
    return DeviceType.expanded;
  }
}
