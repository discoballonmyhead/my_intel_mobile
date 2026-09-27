import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../messaging/presentation/cubits/inbox_cubit.dart';
import '../widgets/nav_destinations.dart';

/// Hosts the persistent navigation around the tabbed branches.
///
/// The whole point of the responsive layer: phones get a bottom bar, anything
/// wider gets a side rail, and the branch state survives the switch because
/// [StatefulNavigationShell] owns it.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns to that branch's first route.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.watch<ResponsiveProvider>();
    final unread =
        context.select<InboxCubit, int>((cubit) => cubit.state.unreadTotal);

    Widget icon(NavDestination d, {required bool selected}) {
      final child = Icon(selected ? d.selectedIcon : d.icon);
      if (!d.showsUnreadBadge || unread == 0) return child;
      return Badge(
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: child,
      );
    }

    if (responsive.useBottomNav) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goToBranch,
          destinations: shellDestinations
              .map((d) => NavigationDestination(
                    icon: icon(d, selected: false),
                    selectedIcon: icon(d, selected: true),
                    label: d.label,
                  ))
              .toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goToBranch,
            // Labels appear once there is room for a full-width rail.
            extended: responsive.isExpanded,
            labelType: responsive.isExpanded
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: const _RailHeader(),
            destinations: shellDestinations
                .map((d) => NavigationRailDestination(
                      icon: icon(d, selected: false),
                      selectedIcon: icon(d, selected: true),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          VerticalDivider(width: 1, color: context.palette.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: IconButton(
        icon: const Icon(Icons.search_rounded),
        tooltip: 'Search',
        onPressed: () => context.push(AppRoutes.search),
      ),
    );
  }
}
