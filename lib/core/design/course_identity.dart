import 'package:flutter/foundation.dart';

/// The saved visual identity of a course, independent of the page showing it.
@immutable
class CourseIdentity {
  const CourseIdentity({
    required this.courseId,
    required this.courseName,
    this.alias,
    this.iconKey,
    this.accentKey,
  });

  final String courseId;
  final String courseName;
  final String? alias;
  final String? iconKey;
  final String? accentKey;

  bool get hasCustomAlias => alias?.trim().isNotEmpty == true;
  String get displayTitle => hasCustomAlias ? alias!.trim() : courseName;

  @override
  bool operator ==(Object other) =>
      other is CourseIdentity &&
      other.courseId == courseId &&
      other.courseName == courseName &&
      other.alias == alias &&
      other.iconKey == iconKey &&
      other.accentKey == accentKey;

  @override
  int get hashCode =>
      Object.hash(courseId, courseName, alias, iconKey, accentKey);
}
