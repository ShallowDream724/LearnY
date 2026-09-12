import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;

import 'app_theme_colors.dart';
import 'course_identity.dart';
import 'course_icons/course_icon.dart';
import 'course_icons/course_icon_catalog.dart';

/// Course identity is independent of urgency and of a course's list position.
enum StudyTone {
  ink('靛蓝', 0xFF5966A9, 0xFF9BBDD7, 0xFF708DE0),
  jade('青玉', 0xFF4C847F, 0xFF8EC2AD, 0xFF5CAF9E),
  ochre('秋麦', 0xFFA5804C, 0xFFDDC194, 0xFFCEA868),
  rose('烟粉', 0xFFAD7488, 0xFFD9A8AC, 0xFFCB8AA5),
  slate('雾蓝', 0xFF6C7E99, 0xFFACBACA, 0xFF7AA4C4),
  plum('藤紫', 0xFF8772AD, 0xFFC0B0D5, 0xFFA08ACD),
  coral('珊瑚', 0xFFB66B61, 0xFFE0A79C, 0xFFD88B7E),
  moss('苔绿', 0xFF72864F, 0xFFB5C68F, 0xFF96B16B),
  lake('湖蓝', 0xFF407E9B, 0xFF8EC3DA, 0xFF60A6C5),
  mauve('木槿', 0xFF9B659D, 0xFFD0A0CE, 0xFFBC87BC),
  amber('琥珀', 0xFFAD7742, 0xFFE0B785, 0xFFD89C60),
  pine('松青', 0xFF508565, 0xFF98C6A8, 0xFF72AB85),
  periwinkle('长春', 0xFF7474B4, 0xFFB8B3E0, 0xFF9993D6),
  raspberry('莓红', 0xFFAC6378, 0xFFDEA0B3, 0xFFD7809B),
  teal('碧潭', 0xFF408B91, 0xFF88CBD0, 0xFF5DB7BE),
  clay('陶棕', 0xFF986F59, 0xFFD3B098, 0xFFBF9376),
  olive('橄榄', 0xFF8A8644, 0xFFC9C48B, 0xFFB4AF64),
  iris('鸢尾', 0xFF8063A1, 0xFFBCA2D3, 0xFFA084C1),
  steel('青灰', 0xFF577D84, 0xFF9BBEC4, 0xFF7DA5AE),
  peach('杏橙', 0xFFB37D68, 0xFFE3B9A6, 0xFFDBA18A);

  const StudyTone(this.label, this.light, this.dark, this.glass);
  final String label;
  final int light;
  final int dark;
  final int glass;

  static StudyTone? fromKey(String? key) {
    final name = key?.startsWith('auto:') == true ? key!.substring(5) : key;
    for (final tone in values) {
      if (tone.name == name) return tone;
    }
    return null;
  }
}

/// Scoped course identities supplied by the app; design widgets need no store.
class CourseIdentityScope extends InheritedWidget {
  const CourseIdentityScope({
    super.key,
    required this.identities,
    required super.child,
  });
  final Map<String, CourseIdentity> identities;

  static CourseIdentity? find(BuildContext context, String courseId) => context
      .dependOnInheritedWidgetOfExactType<CourseIdentityScope>()
      ?.identities[courseId];

  @override
  bool updateShouldNotify(CourseIdentityScope oldWidget) =>
      !mapEquals(identities, oldWidget.identities);
}

class StudyColors {
  const StudyColors(this.accent, this.fill, this.edge);
  final Color accent;
  final Color fill;
  final Color edge;
}

abstract final class StudyPalette {
  static StudyTone course(
    BuildContext context,
    String id, {
    String? accentKey,
  }) {
    return StudyTone.fromKey(accentKey) ??
        StudyTone.fromKey(CourseIdentityScope.find(context, id)?.accentKey) ??
        fallbackCourse(id);
  }

  static StudyTone fallbackCourse(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x1fffffff;
    }
    return StudyTone.values[hash % StudyTone.values.length];
  }

  static StudyColors of(BuildContext context, StudyTone tone) {
    final dark = context.isDark;
    final accent = dark ? tone.dark : tone.light;
    final color = Color(accent);
    return StudyColors(
      color,
      Color.alphaBlend(color.withAlpha(dark ? 24 : 18), context.colors.surface),
      Color.alphaBlend(color.withAlpha(dark ? 46 : 30), context.colors.border),
    );
  }
}

/// A bounded, opaque material. Light is painted once; no backdrop blur or
/// offscreen layers are needed for repeated scrolling content.
class StudySurface extends StatelessWidget {
  const StudySurface({
    super.key,
    required this.child,
    this.tone = StudyTone.slate,
    this.padding = EdgeInsets.zero,
    this.radius = 18,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.mouseCursor,
  });

  final Widget child;
  final StudyTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;
  final MouseCursor? mouseCursor;

  @override
  Widget build(BuildContext context) {
    final colors = StudyPalette.of(context, tone);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: colors.edge.withAlpha(context.isDark ? 120 : 110),
        width: .7,
      ),
    );
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : const Color(0xFF434C78))
                .withAlpha(context.isDark ? 24 : 9),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: (context.isDark ? Colors.black : const Color(0xFF434C78))
                .withAlpha(5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: colors.fill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withAlpha(context.isDark ? 3 : 50),
                  colors.fill,
                ),
                colors.fill,
              ],
            ),
          ),
          child:
              onTap == null && onLongPress == null && onSecondaryTapDown == null
              ? content
              : InkWell(
                  customBorder: shape,
                  mouseCursor: mouseCursor,
                  onTap: onTap,
                  onLongPress: onLongPress,
                  onSecondaryTapDown: onSecondaryTapDown,
                  child: content,
                ),
        ),
      ),
    );
  }
}

/// A small course signature, never used in place of its readable name.
class CourseSeal extends StatelessWidget {
  const CourseSeal({super.key, required this.courseId, this.size = 32})
    : _identity = null;

  /// Editing previews explicitly supply the unsaved draft; regular entries
  /// resolve the saved identity by course ID through the app-wide scope.
  CourseSeal.fromIdentity(CourseIdentity identity, {super.key, this.size = 32})
    : courseId = identity.courseId,
      _identity = identity;

  final String courseId;
  final double size;
  final CourseIdentity? _identity;

  @override
  Widget build(BuildContext context) {
    final identity = _identity ?? CourseIdentityScope.find(context, courseId);
    final tone = StudyPalette.course(
      context,
      courseId,
      accentKey: identity?.accentKey,
    );
    final color = StudyPalette.of(context, tone).accent;
    return CourseIcon(
      option: courseIconFor(
        key: identity?.iconKey,
        courseName: identity?.courseName ?? '',
      ),
      color: Color.lerp(color, context.colors.text, .12)!,
      size: size,
    );
  }
}

class StudyMark extends StatelessWidget {
  const StudyMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/brand/app_icon.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
