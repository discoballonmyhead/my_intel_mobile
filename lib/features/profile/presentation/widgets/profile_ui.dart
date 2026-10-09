import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Shared pieces for the Profile tab and Settings: a quiet top bar, soft
/// rounded row groups, calm messages, fields and buttons. Text that sits in a
/// fresh DefaultTextStyle (app bar titles, buttons) sets Inter explicitly so
/// iOS doesn't fall back to SF Pro.

TextStyle inter(double size,
        {FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
    // letterSpacing 0 so the theme's spaced-out mono title style doesn't leak in.
    GoogleFonts.inter(
        fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: 0);

/// Back arrow and a centred sentence-case title.
PreferredSizeWidget softAppBar(BuildContext context, String title,
    {List<Widget>? actions}) {
  return AppBar(
    centerTitle: true,
    leading: IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    title: Text(title,
        style: inter(17,
            weight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface)),
    actions: actions,
  );
}

/// Small grey heading above a group ("Theme", "Account").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
        child: Text(text,
            style: inter(13, weight: FontWeight.w600, color: context.palette.muted)),
      );
}

/// One row in a [SettingsGroup].
class SettingsRow {
  const SettingsRow({
    required this.title,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.subtitleColor,
    this.value,
    this.titleColor,
    this.onTap,
    this.chevron = true,
    this.checked = false,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final Color? subtitleColor;
  final String? value;
  final Color? titleColor;
  final VoidCallback? onTap;
  final bool chevron;
  final bool checked;
}

/// Rows in one soft rounded card, separated by thin lines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup(this.rows, {super.key});
  final List<SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _row(context, rows[i], palette, onSurface),
              if (i < rows.length - 1)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: rows[i].icon == null ? 16 : 52,
                    endIndent: 16,
                    color: palette.border.withValues(alpha: 0.7)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _titleBlock(SettingsRow r, AppPalette palette, Color onSurface) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(r.title, style: inter(16, color: r.titleColor ?? onSurface)),
          if (r.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(r.subtitle!, style: inter(13, color: r.subtitleColor ?? palette.muted)),
          ],
        ],
      );

  Widget _row(BuildContext context, SettingsRow r, AppPalette palette, Color onSurface) {
    final showChevron = r.chevron && r.onTap != null && !r.checked;
    return InkWell(
      onTap: r.onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: r.subtitle == null ? 52 : 62),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (r.icon != null) ...[
                Icon(r.icon, size: 22, color: r.iconColor ?? palette.muted),
                const SizedBox(width: 14),
              ],
              // With a value, the title keeps its width and the value fills
              // the rest, right-aligned; otherwise the title fills the row.
              if (r.value == null)
                Expanded(child: _titleBlock(r, palette, onSurface))
              else ...[
                _titleBlock(r, palette, onSurface),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(r.value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: inter(15, color: palette.muted)),
                  ),
                ),
              ],
              if (r.checked) Icon(Icons.check_rounded, color: palette.accent),
              if (showChevron) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: palette.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm centred message for empty and error states.
class SoftMessage extends StatelessWidget {
  const SoftMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.filledAction = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final bool filledAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: palette.muted),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: inter(18,
                  weight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: inter(15, color: palette.muted, height: 1.45)),
          if (action != null) ...[
            const SizedBox(height: 22),
            filledAction
                ? PillButton(label: action!, onPressed: onAction, width: 170)
                : PillButton(
                    label: action!, onPressed: onAction, width: 150, soft: true),
          ],
        ],
      ),
    );
  }
}

/// Rounded button: solid red by default, soft grey when [soft].
class PillButton extends StatelessWidget {
  const PillButton({
    required this.label,
    required this.onPressed,
    this.soft = false,
    this.loading = false,
    this.width,
    this.height = 50,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool soft;
  final bool loading;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: soft ? palette.surface2 : palette.accent,
          foregroundColor: soft ? onSurface : Colors.white,
          shape: const StadiumBorder(),
          textStyle: inter(16, weight: FontWeight.w600),
        ),
        child: loading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: soft ? onSurface : Colors.white))
            : Text(label),
      ),
    );
  }
}

/// Label above a soft filled field, with help or error text under it.
class SoftField extends StatefulWidget {
  const SoftField({
    required this.label,
    required this.controller,
    this.hint,
    this.help,
    this.error,
    this.password = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.autofocus = false,
    this.capitalization = TextCapitalization.none,
    super.key,
  });

  final TextCapitalization capitalization;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? help;
  final String? error;
  final bool password;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<SoftField> createState() => _SoftFieldState();
}

class _SoftFieldState extends State<SoftField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final error = widget.error;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: error == null
          ? BorderSide.none
          : BorderSide(color: palette.accent, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(widget.label,
                style: inter(13, weight: FontWeight.w600, color: palette.muted)),
          ),
          TextField(
            controller: widget.controller,
            autofocus: widget.autofocus,
            textCapitalization: widget.capitalization,
            obscureText: widget.password && _hidden,
            maxLines: widget.password ? 1 : widget.maxLines,
            keyboardType: widget.keyboardType,
            autocorrect: !widget.password,
            enableSuggestions: !widget.password,
            onChanged: widget.onChanged,
            style: inter(16, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: inter(16, color: palette.muted),
              filled: true,
              fillColor: palette.surface2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(
                    color: error == null ? palette.border : palette.accent,
                    width: 1.5),
              ),
              suffixIcon: widget.password
                  ? IconButton(
                      tooltip: _hidden ? 'Show password' : 'Hide password',
                      icon: Icon(
                          _hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: palette.muted),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
          ),
          if (error != null || widget.help != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 8),
              child: Text(error ?? widget.help!,
                  style: inter(13, color: error != null ? palette.accent : palette.muted)),
            ),
        ],
      ),
    );
  }
}

/// Bottom-sheet frame used by Edit profile and Sign out.
Future<T?> showSoftSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: builder(sheetContext),
    ),
  );
}
