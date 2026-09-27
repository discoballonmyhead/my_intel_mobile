import 'package:flutter/material.dart';

/// One definition of the tab set, shared by the bottom bar and the nav rail so
/// they can never drift apart.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.showsUnreadBadge = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Wraps the icon in the inbox unread-count badge.
  final bool showsUnreadBadge;
}

const List<NavDestination> shellDestinations = [
  NavDestination(
    label: 'Feed',
    icon: Icons.rss_feed_outlined,
    selectedIcon: Icons.rss_feed_rounded,
  ),
  NavDestination(
    label: 'Intel',
    icon: Icons.newspaper_outlined,
    selectedIcon: Icons.newspaper_rounded,
  ),
  // NavDestination(
  //   label: 'Live',
  //   icon: Icons.podcasts_outlined,
  //   selectedIcon: Icons.podcasts_rounded,
  // ),
  NavDestination(
    label: 'Reels',
    icon: Icons.movie_outlined,
    selectedIcon: Icons.movie_rounded,
  ),
  NavDestination(
    label: 'Messages',
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum_rounded,
    showsUnreadBadge: true,
  ),
  NavDestination(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];
