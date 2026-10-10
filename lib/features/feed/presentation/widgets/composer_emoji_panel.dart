import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Emoji picker that takes the keyboard's place in the composer: category
/// tabs over a grid. Built in, so it needs no extra package.
class ComposerEmojiPanel extends StatefulWidget {
  const ComposerEmojiPanel({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  State<ComposerEmojiPanel> createState() => _ComposerEmojiPanelState();
}

class _ComposerEmojiPanelState extends State<ComposerEmojiPanel> {
  int _tab = 0;

  static const _categories = <(IconData, String, List<String>)>[
    (Icons.sentiment_satisfied_alt_rounded, 'Smileys', [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥲', '😊', '😇', '🙂',
      '🙃', '😉', '😌', '😍', '🥰', '😘', '😋', '😛', '😜', '🤪', '🤨', '🧐',
      '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '😣',
      '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳',
      '🥵', '🥶', '😱', '😨', '😰', '😥', '🤔', '🤫', '🤥', '😶', '😐', '😬',
    ]),
    (Icons.front_hand_rounded, 'People', [
      '👋', '🤚', '✋', '👌', '🤌', '✌️', '🤞', '🤟', '🤘', '👈', '👉', '👆',
      '👇', '☝️', '👍', '👎', '✊', '👊', '👏', '🙌', '👐', '🤝', '🙏', '💪',
      '👀', '🧠', '🫡', '🤷', '🤦', '🙋', '🙅', '🙆', '💁', '🧑‍💻', '🧑‍🚒', '👮',
    ]),
    (Icons.pets_rounded, 'Nature', [
      '🐶', '🐱', '🐭', '🐰', '🦊', '🐻', '🐼', '🐯', '🦁', '🐮', '🐷', '🐸',
      '🐵', '🐔', '🐧', '🐦', '🦅', '🐝', '🌸', '🌻', '🌳', '🌴', '🌵', '🍀',
      '🌍', '🌧️', '⛈️', '🌊', '🔥', '❄️', '🌪️', '🌈', '☀️', '🌙', '⭐', '⚡',
    ]),
    (Icons.fastfood_rounded, 'Food', [
      '🍎', '🍊', '🍌', '🍉', '🍇', '🍓', '🥭', '🍍', '🥥', '🥑', '🌽', '🌶️',
      '🍞', '🧀', '🍳', '🍔', '🍟', '🍕', '🌮', '🍜', '🍛', '🍚', '🍣', '🍩',
      '🍪', '🎂', '🍫', '🍿', '☕', '🍵', '🥤', '🧃', '🍺', '🥂', '🍷', '🧋',
    ]),
    (Icons.sports_soccer_rounded, 'Activity', [
      '⚽', '🏀', '🏈', '⚾', '🎾', '🏏', '🏑', '🏓', '🏸', '🥊', '🏆', '🥇',
      '🎯', '🎮', '🎲', '🎨', '🎬', '🎤', '🎧', '🎸', '🥁', '🎻', '🚴', '🏃',
    ]),
    (Icons.flight_rounded, 'Travel', [
      '🚗', '🚕', '🚌', '🚑', '🚒', '🚓', '🚚', '🚜', '🏍️', '🚲', '🚂', '🚇',
      '✈️', '🚁', '🚀', '⛵', '🚢', '⚓', '🗺️', '🏙️', '🏠', '🏥', '🏫', '🏛️',
    ]),
    (Icons.lightbulb_outline_rounded, 'Objects', [
      '📱', '💻', '⌚', '📷', '🎥', '📺', '📻', '🔦', '💡', '🔋', '📰', '📢',
      '📣', '🔔', '📌', '📍', '🔒', '🔑', '🧭', '⏰', '📅', '✉️', '📦', '🛡️',
    ]),
    (Icons.flag_outlined, 'Symbols', [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💔', '❗', '❓', '⚠️',
      '✅', '❌', '⛔', '🚫', '♻️', '🆘', '🔴', '🟠', '🟡', '🟢', '🔵', '🏳️',
      '🇮🇳', '🇺🇸', '🇬🇧', '🇺🇦', '🇮🇱', '🇵🇸', '🇨🇳', '🇵🇰', '🇧🇩', '🇳🇵', '🇱🇰', '🇯🇵',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final emojis = _categories[_tab].$3;

    return Container(
      height: 280,
      color: palette.surface2,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (var i = 0; i < _categories.length; i++)
                  Expanded(
                    child: Semantics(
                      label: _categories[i].$2,
                      selected: i == _tab,
                      button: true,
                      child: InkWell(
                        onTap: () => setState(() => _tab = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_categories[i].$1,
                                size: 20,
                                color: i == _tab ? palette.accent : palette.muted),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 2,
                              width: i == _tab ? 22 : 0,
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
                onTap: () => widget.onPick(emojis[i]),
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
