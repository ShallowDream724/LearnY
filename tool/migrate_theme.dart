// Phase 3: Replace old variable USAGES with c.xxx equivalents.
//
// Phase 1 removed ternary declarations.
// Phase 2 removed isDark params.
// Phase 3 replaces dangling variable names with c.xxx.
import 'dart:io';

final files = [
  'lib/features/search/search_screen.dart',
  'lib/features/profile/profile_screen.dart',
  'lib/features/notifications/notification_detail_screen.dart',
  'lib/features/home/home_screen.dart',
  'lib/features/files/unread_files_screen.dart',
  'lib/features/files/file_detail_screen.dart',
  'lib/features/files/file_manager_screen.dart',
  'lib/features/files/files_screen.dart',
  'lib/features/courses/course_detail_screen.dart',
  'lib/features/courses/courses_screen.dart',
  'lib/features/auth/login_screen.dart',
  'lib/features/assignments/assignments_screen.dart',
  'lib/features/assignments/homework_detail_screen.dart',
  'lib/core/shell/app_shell.dart',
  'lib/core/design/swipe_to_read.dart',
  'lib/core/design/shimmer.dart',
  'lib/features/home/widgets/urgent_deadline_banner.dart',
];

/// Ordered from longest to shortest to avoid partial matches.
/// E.g. 'subtitleColor' must be matched before 'Color'.
final replacements = [
  // Multi-word names first
  (RegExp(r'(?<![a-zA-Z_])tertiaryColor(?![a-zA-Z_])'), 'c.tertiary'),
  (RegExp(r'(?<![a-zA-Z_])subtitleColor(?![a-zA-Z_])'), 'c.subtitle'),
  (RegExp(r'(?<![a-zA-Z_])textColor(?![a-zA-Z_])'), 'c.text'),
  (RegExp(r'(?<![a-zA-Z_])subColor(?![a-zA-Z_])'), 'c.subtitle'),
  
  // Context-sensitive: only replace when used as a color value, not as a keyword
  // "color: surface" or "= surface;" but not "class Surface" or "Widget surface"
  // We use lookbehind for ": " or "= " to ensure color context
  (RegExp(r'(?<=color: )bg(?=[,;\)\s])'), 'c.bg'),
  (RegExp(r'(?<=Color: )bg(?=[,;\)\s])'), 'c.bg'),
  (RegExp(r'(?<=olor: )surface(?=[,;\)\s])'), 'c.surface'),
  (RegExp(r'(?<=olor: )border(?=[,;\)\s])'), 'c.border'),
  
  // Also handle "color: sub," pattern
  (RegExp(r'(?<=color: )sub(?=[,;\)\s])'), 'c.subtitle'),
  (RegExp(r'(?<=color: )tertiary(?=[,;\)\s])'), 'c.tertiary'),
  
  // Handle scaffold/appbar background color assignments
  (RegExp(r'backgroundColor: bg(?=[,;\)\s])'), 'backgroundColor: c.bg'),
];

void main() {
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      stdout.writeln('SKIP: $path');
      continue;
    }
    var content = file.readAsStringSync();
    int changes = 0;

    for (final (pattern, replacement) in replacements) {
      final matches = pattern.allMatches(content).length;
      if (matches > 0) {
        content = content.replaceAll(pattern, replacement);
        changes += matches;
      }
    }

    // Also clean up awkward multi-line remains from phase 1
    // e.g. "final textColor =\n        c.text;" → just remove (already using c.text)
    final multiLineCleanup = RegExp(
      r'    final \w+ =\n\s+c\.\w+;\n',
      multiLine: true,
    );
    final multiLineMatches = multiLineCleanup.allMatches(content).length;
    if (multiLineMatches > 0) {
      content = content.replaceAll(multiLineCleanup, '');
      changes += multiLineMatches;
    }

    // Also single-line: "final textColor = c.text;"
    final singleLineCleanup = RegExp(
      r'    final \w+ = c\.\w+;\n',
      multiLine: true,
    );
    final singleLineMatches = singleLineCleanup.allMatches(content).length;
    if (singleLineMatches > 0) {
      content = content.replaceAll(singleLineCleanup, '');
      changes += singleLineMatches;
    }

    if (changes > 0) {
      file.writeAsStringSync(content);
      stdout.writeln('PHASE3 ($changes fixes): $path');
    } else {
      stdout.writeln('NO CHANGE: $path');
    }
  }
  stdout.writeln('\nPhase 3 done!');
}
