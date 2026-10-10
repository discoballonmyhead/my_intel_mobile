import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/story.dart';
import '../providers/story_provider.dart';

/// Sentence-case label for a window, e.g. "Past hour", "All time".
String intelWindowLabel(TimeWindow w) => switch (w) {
      TimeWindow.hour => 'Past hour',
      TimeWindow.day => 'Past 24h',
      TimeWindow.week => 'Past week',
      TimeWindow.all => 'All time',
    };

/// "Conflict" from "CONFLICT".
String intelTopicLabel(String tag) => tag[0] + tag.substring(1).toLowerCase();

/// Bottom sheet with every Intel filter: topics, time, confidence and
/// breaking only. Returns the new filters, or null when dismissed.
class IntelFilterSheet extends StatefulWidget {
  const IntelFilterSheet({
    required this.initial,
    required this.loaded,
    required this.loadedFilters,
    super.key,
  });

  final IntelFilters initial;

  /// Stories currently fetched, used to preview the result count.
  final List<Story> loaded;
  final IntelFilters loadedFilters;

  static Future<IntelFilters?> show(
      BuildContext context, StoryProvider provider) {
    return showModalBottomSheet<IntelFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => IntelFilterSheet(
        initial: provider.filters,
        loaded: provider.stories,
        loadedFilters: provider.filters,
      ),
    );
  }

  @override
  State<IntelFilterSheet> createState() => _IntelFilterSheetState();
}

class _IntelFilterSheetState extends State<IntelFilterSheet> {
  late IntelFilters _draft = widget.initial;

  /// Count is only known when the time window is the one already loaded.
  int? get _count => _draft.window == widget.loadedFilters.window
      ? widget.loaded.where(_draft.matches).length
      : null;

  void _toggleTopic(String tag) {
    final topics = {..._draft.topics};
    topics.contains(tag) ? topics.remove(tag) : topics.add(tag);
    setState(() => _draft = _draft.copyWith(topics: topics));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = _count;
    final label = count == null
        ? 'Show stories'
        : 'Show $count ${count == 1 ? 'story' : 'stories'}';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: _draft == IntelFilters.none
                      ? null
                      : () => setState(() => _draft = IntelFilters.none),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.accent,
                    textStyle: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const _Heading('Topics'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in AppConstants.mapFilters.skip(1))
                  _Chip(
                    label: intelTopicLabel(tag),
                    selected: _draft.topics.contains(tag),
                    onTap: () => _toggleTopic(tag),
                  ),
              ],
            ),
            const _Heading('Time'),
            _Segmented<TimeWindow>(
              values: TimeWindow.values,
              selected: _draft.window,
              label: (w) => w == TimeWindow.day ? '24h' : intelWindowLabel(w),
              onChanged: (w) =>
                  setState(() => _draft = _draft.copyWith(window: w)),
            ),
            const _Heading('Confidence'),
            _Segmented<MinConfidence>(
              values: MinConfidence.values,
              selected: _draft.minConfidence,
              label: (c) => c.label,
              onChanged: (c) =>
                  setState(() => _draft = _draft.copyWith(minConfidence: c)),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('Breaking only', style: TextStyle(fontSize: 16)),
              value: _draft.breakingOnly,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(breakingOnly: v)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_draft),
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.palette.muted)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.onSurface : context.palette.surface2,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? scheme.surface : scheme.onSurface)),
          ),
        ),
      ),
    );
  }
}

/// Rounded segmented control: the selected option sits on a raised pill.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == selected
                          ? theme.scaffoldBackgroundColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(label(v),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: v == selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: v == selected
                                ? theme.colorScheme.onSurface
                                : palette.muted)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
