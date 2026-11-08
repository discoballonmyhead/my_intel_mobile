import 'package:equatable/equatable.dart';

/// What the feed does with the compass.
enum LeanMode {
  /// The normal ranked feed.
  off,

  /// The best posts from all four corners take turns.
  balanced,

  /// More posts from the corner opposite to yours.
  opposite,

  /// More posts near a point the user picked.
  spot;

  static LeanMode fromValue(String? value) =>
      values.firstWhere((m) => m.name == value, orElse: () => off);
}

/// A point on the compass. x: economic left (−1) ↔ right (+1).
/// y: libertarian (−1, bottom) ↔ authoritarian (+1, top).
class LeanPoint extends Equatable {
  const LeanPoint(this.x, this.y);

  final double x;
  final double y;

  static const LeanPoint centre = LeanPoint(0, 0);

  LeanPoint clamp() => LeanPoint(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));

  static LeanPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    final x = json['x'], y = json['y'];
    if (x is! num || y is! num) return null;
    return LeanPoint(x.toDouble(), y.toDouble());
  }

  /// "Up-left", "Down-right", … or "Centre" when close to the middle.
  String get quadrant {
    if (x.abs() < 0.1 && y.abs() < 0.1) return 'Centre';
    final v = y >= 0 ? 'Up' : 'Down';
    final h = x >= 0 ? 'right' : 'left';
    return '$v-$h';
  }

  /// Plain-words reading of the point.
  String get describe {
    if (x.abs() < 0.1 && y.abs() < 0.1) return 'Near the centre';
    String part(double v, String neg, String pos) {
      final a = v.abs();
      if (a < 0.1) return '';
      final how = a < 0.35 ? 'slightly ' : (a < 0.7 ? '' : 'strongly ');
      return '$how${v < 0 ? neg : pos}';
    }

    final parts = [
      part(x, 'left', 'right'),
      part(y, 'libertarian', 'authoritarian'),
    ].where((p) => p.isNotEmpty).toList();
    final text = parts.join(', ');
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  List<Object?> get props => [x, y];
}

/// The signed-in user's compass, as the server computed it.
class LeanStatus extends Equatable {
  const LeanStatus({
    this.enabled = false,
    this.mode = LeanMode.off,
    this.spot,
    this.position,
    this.items = 0,
    this.trail = const [],
    this.consentedAt,
  });

  final bool enabled;
  final LeanMode mode;
  final LeanPoint? spot;
  final LeanPoint? position;

  /// Classified likes the position is based on.
  final int items;

  /// Oldest first; the last one is the current position.
  final List<LeanPoint> trail;
  final DateTime? consentedAt;

  static const LeanStatus disabled = LeanStatus();

  bool get hasPosition => position != null && items > 0;

  /// Where the filter steers the feed (null: nowhere in particular).
  LeanPoint? get target => switch (mode) {
        LeanMode.spot => spot,
        LeanMode.opposite when hasPosition => LeanPoint(-position!.x, -position!.y),
        _ => null,
      };

  factory LeanStatus.fromJson(Map<String, dynamic> json) {
    final pos = json['position'];
    return LeanStatus(
      enabled: json['enabled'] == true,
      mode: LeanMode.fromValue(json['mode'] as String?),
      spot: LeanPoint.fromJson(json['spot']),
      position: LeanPoint.fromJson(pos),
      items: pos is Map && pos['items'] is num ? (pos['items'] as num).toInt() : 0,
      trail: [
        for (final t in (json['trail'] as List? ?? const []))
          if (LeanPoint.fromJson(t) case final p?) p,
      ],
      consentedAt: DateTime.tryParse('${json['consented_at'] ?? ''}'),
    );
  }

  @override
  List<Object?> get props => [enabled, mode, spot, position, items, trail, consentedAt];
}
