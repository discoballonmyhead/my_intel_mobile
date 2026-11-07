import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';

/// Emoji picker that takes the keyboard's place in the composer: category
/// tabs over a grid, with a Recently used tab first once you've picked some.
/// Built in, so it needs no extra package.
class ComposerEmojiPanel extends StatefulWidget {
  const ComposerEmojiPanel({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  State<ComposerEmojiPanel> createState() => _ComposerEmojiPanelState();
}

class _ComposerEmojiPanelState extends State<ComposerEmojiPanel> {
  static const _recentKey = 'emoji_recent';
  static const _recentMax = 24;

  int _tab = 0;
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecent());
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_recentKey) ?? const <String>[];
      if (mounted && saved.isNotEmpty) setState(() => _recent = saved);
    } catch (_) {
      // Recently used is a nicety; the panel works without it.
    }
  }

  void _pick(String emoji) {
    widget.onPick(emoji);
    final next = recentAfterPick(_recent, emoji, max: _recentMax);
    // Keep the grid still while picking; the new order shows next time.
    _recent = next;
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setStringList(_recentKey, next))
        .catchError((_) => false));
  }

  static const _categories = <(IconData, String, List<String>)>[
    (
      Icons.sentiment_satisfied_alt_rounded,
      'Smileys',
      [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '😂',
        '🤣',
        '🥲',
        '😊',
        '😇',
        '🙂',
        '🙃',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😋',
        '😛',
        '😜',
        '🤪',
        '🤨',
        '🧐',
        '🤓',
        '😎',
        '🤩',
        '🥳',
        '😏',
        '😒',
        '😞',
        '😔',
        '😟',
        '😕',
        '🙁',
        '😣',
        '😖',
        '😫',
        '😩',
        '🥺',
        '😢',
        '😭',
        '😤',
        '😠',
        '😡',
        '🤬',
        '🤯',
        '😳',
        '🥵',
        '🥶',
        '😱',
        '😨',
        '😰',
        '😥',
        '🤔',
        '🤫',
        '🤥',
        '😶',
        '😐',
        '😬',
      ]
    ),
    (
      Icons.front_hand_rounded,
      'People',
      [
        '👋',
        '🤚',
        '✋',
        '👌',
        '🤌',
        '✌️',
        '🤞',
        '🤟',
        '🤘',
        '👈',
        '👉',
        '👆',
        '👇',
        '☝️',
        '👍',
        '👎',
        '✊',
        '👊',
        '👏',
        '🙌',
        '👐',
        '🤝',
        '🙏',
        '💪',
        '👀',
        '🧠',
        '🫡',
        '🤷',
        '🤦',
        '🙋',
        '🙅',
        '🙆',
        '💁',
        '🧑‍💻',
        '🧑‍🚒',
        '👮',
      ]
    ),
    (
      Icons.pets_rounded,
      'Nature',
      [
        '🐶',
        '🐱',
        '🐭',
        '🐰',
        '🦊',
        '🐻',
        '🐼',
        '🐯',
        '🦁',
        '🐮',
        '🐷',
        '🐸',
        '🐵',
        '🐔',
        '🐧',
        '🐦',
        '🦅',
        '🐝',
        '🌸',
        '🌻',
        '🌳',
        '🌴',
        '🌵',
        '🍀',
        '🌍',
        '🌧️',
        '⛈️',
        '🌊',
        '🔥',
        '❄️',
        '🌪️',
        '🌈',
        '☀️',
        '🌙',
        '⭐',
        '⚡',
      ]
    ),
    (
      Icons.fastfood_rounded,
      'Food',
      [
        '🍎',
        '🍊',
        '🍌',
        '🍉',
        '🍇',
        '🍓',
        '🥭',
        '🍍',
        '🥥',
        '🥑',
        '🌽',
        '🌶️',
        '🍞',
        '🧀',
        '🍳',
        '🍔',
        '🍟',
        '🍕',
        '🌮',
        '🍜',
        '🍛',
        '🍚',
        '🍣',
        '🍩',
        '🍪',
        '🎂',
        '🍫',
        '🍿',
        '☕',
        '🍵',
        '🥤',
        '🧃',
        '🍺',
        '🥂',
        '🍷',
        '🧋',
      ]
    ),
    (
      Icons.sports_soccer_rounded,
      'Activity',
      [
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🎾',
        '🏏',
        '🏑',
        '🏓',
        '🏸',
        '🥊',
        '🏆',
        '🥇',
        '🎯',
        '🎮',
        '🎲',
        '🎨',
        '🎬',
        '🎤',
        '🎧',
        '🎸',
        '🥁',
        '🎻',
        '🚴',
        '🏃',
      ]
    ),
    (
      Icons.flight_rounded,
      'Travel',
      [
        '🚗',
        '🚕',
        '🚌',
        '🚑',
        '🚒',
        '🚓',
        '🚚',
        '🚜',
        '🏍️',
        '🚲',
        '🚂',
        '🚇',
        '✈️',
        '🚁',
        '🚀',
        '⛵',
        '🚢',
        '⚓',
        '🗺️',
        '🏙️',
        '🏠',
        '🏥',
        '🏫',
        '🏛️',
      ]
    ),
    (
      Icons.lightbulb_outline_rounded,
      'Objects',
      [
        '📱',
        '💻',
        '⌚',
        '📷',
        '🎥',
        '📺',
        '📻',
        '🔦',
        '💡',
        '🔋',
        '📰',
        '📢',
        '📣',
        '🔔',
        '📌',
        '📍',
        '🔒',
        '🔑',
        '🧭',
        '⏰',
        '📅',
        '✉️',
        '📦',
        '🛡️',
      ]
    ),
    (
      Icons.flag_outlined,
      'Symbols',
      [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '💔',
        '❗',
        '❓',
        '⚠️',
        '✅',
        '❌',
        '⛔',
        '🚫',
        '♻️',
        '🆘',
        '🔴',
        '🟠',
        '🟡',
        '🟢',
        '🔵',
        '🏳️',
        '🇮🇳',
        '🇺🇸',
        '🇬🇧',
        '🇺🇦',
        '🇮🇱',
        '🇵🇸',
        '🇨🇳',
        '🇵🇰',
        '🇧🇩',
        '🇳🇵',
        '🇱🇰',
        '🇯🇵',
      ]
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tabs = [
      if (_recent.isNotEmpty)
        (Icons.schedule_rounded, 'Recently used', _recent),
      ..._categories,
    ];
    final tab = _tab.clamp(0, tabs.length - 1);
    final emojis = tabs[tab].$3;

    return Container(
      height: 280,
      color: palette.surface2,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      label: tabs[i].$2,
                      selected: i == tab,
                      button: true,
                      child: InkWell(
                        onTap: () => setState(() => _tab = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tabs[i].$1,
                                size: 20,
                                color:
                                    i == tab ? palette.accent : palette.muted),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 2,
                              width: i == tab ? 22 : 0,
                              color: palette.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border.withValues(alpha: 0.6)),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8),
              itemCount: emojis.length,
              itemBuilder: (context, i) => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _pick(emojis[i]),
                child: Center(
                  child: Text(emojis[i], style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [recent] with [emoji] moved to the front, at most [max] long.
List<String> recentAfterPick(List<String> recent, String emoji,
        {int max = 24}) =>
    [emoji, ...recent.where((e) => e != emoji)].take(max).toList();
