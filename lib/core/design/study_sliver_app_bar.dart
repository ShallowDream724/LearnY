import 'package:flutter/material.dart';
import 'study_readable_content.dart';

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
    super.actionsPadding,
    super.toolbarHeight,
    super.pinned,
    super.floating,
    super.snap,
  }) : super(
         title: StudyHeaderContent(child: title),
         leading: leading == null
             ? null
             : StudyHeaderContent.actions(child: leading),
         actions: actions.isEmpty
             ? null
             : [
                 StudyHeaderContent.actions(
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: actions,
                   ),
                 ),
               ],
         backgroundColor: Colors.transparent,
         surfaceTintColor: Colors.transparent,
         shadowColor: Colors.transparent,
         clipBehavior: Clip.none,
         // Ordinary scrolling headers reveal the shared wallpaper directly.
         // Only overlapping headers need to mask passing content.
         flexibleSpace: pinned == true || floating == true
             ? const StudyLightSurface()
             : null,
       );
}
