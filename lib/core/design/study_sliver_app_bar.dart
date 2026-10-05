import 'package:flutter/material.dart';
import 'study_header_content.dart';

/// Shared scrolling headings and bounded actions for the four shell pages.
/// An explicit background is reserved for a persistent editing toolbar.
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
    Color backgroundColor = Colors.transparent,
  }) : super(
         title: StudyHeaderContent(
           onWallpaper: backgroundColor.a == 0,
           child: title,
         ),
         leading: leading == null
             ? null
             : StudyHeaderContent.actions(
                 onWallpaper: backgroundColor.a == 0,
                 child: leading,
               ),
         actions: actions.isEmpty
             ? null
             : [
                 StudyHeaderContent.actions(
                   onWallpaper: backgroundColor.a == 0,
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: actions,
                   ),
                 ),
               ],
         backgroundColor: backgroundColor,
         surfaceTintColor: Colors.transparent,
         shadowColor: Colors.transparent,
         clipBehavior: Clip.hardEdge,
       );
}
