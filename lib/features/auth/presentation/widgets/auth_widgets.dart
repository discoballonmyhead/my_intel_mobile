import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'radar_backdrop.dart';

/// Top row of the auth screens: optional back button and a blinking status
/// readout ("● INCOMING REPORTS").
class AuthStatusBar extends StatelessWidget {
  const AuthStatusBar({
    required this.label,
    this.onBack,
    this.dotColor,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback? onBack;
  final Color? dotColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final readout = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BlinkingDot(color: dotColor ?? palette.accent),
        const SizedBox(width: 7),
        Text(label,
            style: AppTypography.mono(
                size: 9,
                weight: FontWeight.w700,
                color: palette.muted,
                letterSpacing: 1.8)),
      ],
    );

    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 12),
            if (onBack != null) const Spacer(),
            readout,
            const Spacer(),
            if (trailing != null) trailing!,
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.color});
  final Color color;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _c.value < 0.5 ? widget.color : Colors.transparent,
        ),
      ),
    );
  }
}

/// Rounded text field used across the auth forms, with an optional
/// show / hide toggle for passwords.
class AuthField extends StatefulWidget {
  const AuthField({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscurable = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscurable;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscurable && _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: !widget.obscurable,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        isDense: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        prefixIcon: widget.icon == null
            ? null
            : Icon(widget.icon, size: 18, color: palette.muted),
        suffixIcon: widget.obscurable
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                  color: palette.muted,
                ),
              )
            : null,
        border: border(palette.border),
        enabledBorder: border(palette.border),
        focusedBorder: border(palette.accent, 1.5),
        errorBorder: border(palette.accent2),
        focusedErrorBorder: border(palette.accent2, 1.5),
      ),
    );
  }
}

/// Primary call to action: full width, brand red, mono label and an arrow.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: palette.border,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: onAccent),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: AppTypography.mono(
                          size: 13,
                          weight: FontWeight.w800,
                          letterSpacing: 2)),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
      ),
    );
  }
}

/// "Sign in | Create account" switch with a sliding pill.
class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    required this.signUp,
    required this.onChanged,
    super.key,
  });

  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget tab(String label, bool value) {
      final selected = signUp == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: selected
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged(value);
                  },
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Theme.of(context).colorScheme.surface
                      : palette.muted,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: signUp ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: onSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Row(children: [tab('Sign in', false), tab('Create account', true)]),
        ],
      ),
    );
  }
}

/// Reader / Reporter choice shown on Create account.
class RolePicker extends StatelessWidget {
  const RolePicker({required this.value, required this.onChanged, super.key});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JOIN AS',
            style: AppTypography.mono(
                size: 9,
                weight: FontWeight.w700,
                color: palette.muted,
                letterSpacing: 1.8)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _RoleCard(
                title: 'Reader',
                description: 'Follow, react and discuss intel',
                icon: Icons.visibility_outlined,
                selected: value == UserRole.public,
                onTap: () => onChanged(UserRole.public),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RoleCard(
                title: 'Reporter',
                description: 'Post reports from the ground',
                icon: Icons.edit_outlined,
                selected: value == UserRole.reporter,
                onTap: () => onChanged(UserRole.reporter),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final surface = Theme.of(context).colorScheme.surface;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$title. $description',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? surface : surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? palette.accent : palette.border, width: 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? palette.accent : palette.surface2,
                ),
                child: Icon(icon,
                    size: 16,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : palette.muted),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: TextStyle(
                            fontSize: 11, height: 1.3, color: palette.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big bold title plus a muted line of body copy.
class AuthHeading extends StatelessWidget {
  const AuthHeading({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DefaultTextStyle.merge(
          style: TextStyle(
              fontSize: 15, height: 1.5, color: context.palette.muted),
          child: body,
        ),
      ],
    );
  }
}

/// Hero for the recovery / verification screens: the radar with one floating
/// icon card in the middle, optionally sending out signal waves.
class RecoveryStage extends StatefulWidget {
  const RecoveryStage({
    required this.icon,
    required this.caption,
    this.tint,
    this.waves = false,
    super.key,
  });

  final IconData icon;
  final String caption;
  final Color? tint;
  final bool waves;

  @override
  State<RecoveryStage> createState() => _RecoveryStageState();
}

class _RecoveryStageState extends State<RecoveryStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = widget.tint ?? palette.accent;
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          const RadarBackdrop(diameter: 300, showTicks: false),
          if (widget.waves)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  for (final offset in const [0.0, 0.5])
                    Builder(builder: (context) {
                      final p = ((_c.value * 5 / 2.4) + offset) % 1;
                      return Transform.scale(
                        scale: 0.5 + 1.9 * p,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: tint.withValues(alpha: 0.5 * (1 - p)),
                                width: 2),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                  0, -6 * (0.5 - 0.5 * math.cos(2 * math.pi * _c.value))),
              child: Transform.rotate(angle: -2 * math.pi / 180, child: child),
            ),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 44,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint.withValues(alpha: 0.12),
                    ),
                    child: Icon(widget.icon, size: 28, color: tint),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.caption,
                      style: AppTypography.mono(
                          size: 8,
                          weight: FontWeight.w700,
                          color: palette.muted,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four-bar strength meter plus live requirement checks for a new password.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    required this.password,
    required this.confirm,
    super.key,
  });

  final String password;
  final String confirm;

  static int score(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[0-9]').hasMatch(p) && RegExp(r'[a-zA-Z]').hasMatch(p)) s++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = score(password);
    final colors = [
      palette.accent,
      palette.warn,
      const Color(0xFFE0A800),
      palette.verified,
    ];

    Widget check(bool ok, String label) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ok ? palette.verified : Colors.transparent,
                  border: ok ? null : Border.all(color: palette.border, width: 1.5),
                ),
                child: ok
                    ? Icon(Icons.check_rounded,
                        size: 11, color: Theme.of(context).colorScheme.surface)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: ok ? palette.verified : palette.muted)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < s ? colors[s - 1] : palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        check(password.length >= 8, 'At least 8 characters'),
        check(password.isNotEmpty && password == confirm, 'Passwords match'),
      ],
    );
  }
}

/// "Resend" text button with a cool-down, so people don't hammer the mail
/// endpoint. Starts counting down straight away (a link was just sent).
class ResendButton extends StatefulWidget {
  const ResendButton({required this.onResend, this.seconds = 30, super.key});

  /// Returns true when the resend went through, which restarts the timer.
  final Future<bool> Function() onResend;
  final int seconds;

  @override
  State<ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<ResendButton> {
  late int _left = widget.seconds;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _left = widget.seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) t.cancel();
      setState(() => _left = math.max(0, _left - 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    final ok = await widget.onResend();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _start();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final waiting = _left > 0;
    return TextButton(
      onPressed: waiting || _busy ? null : _resend,
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        disabledForegroundColor: palette.muted,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        minimumSize: const Size(44, 44),
      ),
      child: Text(waiting
          ? 'Resend in 0:${_left.toString().padLeft(2, '0')}'
          : 'Resend link'),
    );
  }
}

/// Small bordered hint ("Not there? Check your spam folder.").
class AuthTip extends StatelessWidget {
  const AuthTip({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: palette.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, height: 1.4, color: palette.muted)),
          ),
        ],
      ),
    );
  }
}
