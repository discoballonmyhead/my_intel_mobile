import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Listenable] (our AuthProvider) into GoRouter's `refreshListenable`
/// without GoRouter needing to know what it is listening to.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Listenable listenable) {
    _listenable = listenable;
    _listenable.addListener(_onChange);
  }

  late final Listenable _listenable;

  void _onChange() {
    // Coalesce bursts of notifications into a single router refresh.
    scheduleMicrotask(notifyListeners);
  }

  @override
  void dispose() {
    _listenable.removeListener(_onChange);
    super.dispose();
  }
}
