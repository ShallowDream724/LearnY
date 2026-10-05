import 'package:flutter/material.dart';
import 'app_light_scene.dart';

/// Shared wallpaper continuity and local contrast for the four shell pages.
/// Scroll behavior stays explicit at the call site.
class StudySliverAppBar extends SliverAppBar {
  StudySliverAppBar({
    super.key,
    required Widget title,
    List<Widget> actions = const [],
    Widget? leading,
    super.leadingWidth,
    super.titleSpacing,
    super.toolbarHeight,
    super.pinned,
    super.floating,
    super.snap,
  }) : super(
         title: StudyHeaderContent(child: title),
         leading: leading == null ? null : StudyHeaderContent(child: leading),
         actions: actions.isEmpty
             ? null
             : [
                 StudyHeaderContent(
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: actions,
                   ),
                 ),
               ],
         backgroundColor: Colors.transparent,
         surfaceTintColor: Colors.transparent,
         shadowColor: Colors.transparent,
         flexibleSpace: const StudyLightSurface(),
       );
}
