import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/profile.dart';
import 'edit_profile_sheet.dart';
import 'profile_ui.dart';

/// Initial on a soft red halo, the username, About me, one line of numbers
/// (followers and following open their lists) and Edit profile.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.profile,
    required this.stats,
    required this.onFollowers,
    required this.onFollowing,
    required this.onEdit,
    this.bio,
    super.key,
  });

  final Profile profile;
  final FollowStats stats;
  final String? bio;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final initial =
        profile.username.isEmpty ? '?' : profile.username[0].toUpperCase();
    final muted = inter(14, color: palette.muted);

    Widget stat(String text, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(text, style: muted),
          ),
        );
    Widget dot() => Text('·', style: muted);

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      palette.accent.withValues(alpha: 0.14),
                      palette.accent.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Text(initial,
                    style: inter(30, weight: FontWeight.w600, color: palette.accent)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(profile.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: inter(22, weight: FontWeight.w600, color: onSurface)),
        ),
        if (kAboutMeEnabled) ...[
          const SizedBox(height: 8),
          if (bio case final text? when text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: inter(15, color: onSurface, height: 1.45)),
            )
          else
            InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('+ Add a short bio',
                    style: inter(15, weight: FontWeight.w500, color: palette.muted)),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            stat('${stats.followers} followers', onFollowers),
            dot(),
            stat('${stats.following} following', onFollowing),
            dot(),
            stat('${profile.auraPoints} aura', null),
            if (profile.isAnalyst) ...[dot(), stat('${profile.score} cred', null)],
          ],
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(
            foregroundColor: palette.accent,
            textStyle: inter(15, weight: FontWeight.w500),
          ),
          child: const Text('Edit profile'),
        ),
      ],
    );
  }
}
