import 'package:flutter/material.dart';

/// One definition of the tab set, shared by the bottom bar and the nav rail so
/// they can never drift apart.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
  NavDestination(
    label: 'Live',
    icon: Icons.podcasts_outlined,
    selectedIcon: Icons.podcasts_rounded,
  ),
  NavDestination(
    label: 'Reels',
    icon: Icons.movie_outlined,
    selectedIcon: Icons.movie_rounded,
  ),
  NavDestination(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];
