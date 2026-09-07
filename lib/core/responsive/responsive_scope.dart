import 'package:flutter/material.dart';
import 'package:mint/core/responsive/breakpoints.dart';
import 'package:provider/provider.dart';

import 'responsive_provider.dart';

/// Feeds MediaQuery into [ResponsiveProvider]. Wrap the app once, below
/// MaterialApp's builder, so rotation and window resizes propagate.
class ResponsiveScope extends StatelessWidget {
  const ResponsiveScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    context.read<ResponsiveProvider>().update(MediaQuery.of(context));
    return child;
  }
}

/// Picks one of three subtrees by breakpoint. Falls back down the scale when a
/// larger variant is not supplied.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    final responsive = context.watch<ResponsiveProvider>();
    final builder = switch (responsive.deviceType) {
      DeviceType.compact => compact,
      DeviceType.medium => medium ?? compact,
      DeviceType.expanded => expanded ?? medium ?? compact,
    };
    return builder(context);
  }
}

/// Constrains content to a readable column and centres it on wide screens,
/// while staying edge-to-edge on phones.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    required this.child,
    this.maxWidth = 680,
    this.padded = true,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final responsive = context.watch<ResponsiveProvider>();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padded
              ? EdgeInsets.symmetric(horizontal: responsive.horizontalGutter)
              : EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
