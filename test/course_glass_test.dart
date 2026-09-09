import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/app_light_scene.dart';
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/core/design/course_glass.dart';
import 'package:learn_y/core/design/wallpaper.dart';

void main() {
  testWidgets('cached course glass survives background changes and returns', (
    tester,
  ) async {
    final controller = PageController();
    final cardKey = GlobalKey();
    addTearDown(controller.dispose);

    Widget app({required double strength, required Brightness brightness}) =>
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: StudyLightBackdrop(
            strength: strength,
            child: PageView(
              controller: controller,
              children: [
                _RetainedCourse(cardKey: cardKey),
                const ColoredBox(color: Colors.white),
              ],
            ),
          ),
        );

    await tester.pumpWidget(app(strength: .3, brightness: Brightness.light));
    final firstContext = cardKey.currentContext!;
    await tester.runAsync(
      () => precacheImage(
        AssetImage(StudyWallpaper.dunes.assetFor(Brightness.light)),
        firstContext,
      ),
    );
    await tester.pumpAndSettle();
    final card = cardKey.currentContext!.findRenderObject()! as RenderBox;
    final original = StudyLightBackdrop.locate(card, dark: false).origin;
    expect(original.isFinite, isTrue);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      // The retained page still owns a repaint boundary, but the viewport
      // deliberately cannot map it to the screen while it is in its cache.
      final hidden = MatrixUtils.transformPoint(
        card.getTransformTo(null),
        Offset.zero,
      );
      expect(hidden.isFinite, isFalse);

      await tester.pumpWidget(app(strength: .65, brightness: brightness));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      controller.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('课程卡片'), findsOneWidget);
      expect(StudyLightBackdrop.locate(card, dark: false).origin, original);
    }
    await tester.pumpWidget(const SizedBox());
  });
}

class _RetainedCourse extends StatefulWidget {
  const _RetainedCourse({required this.cardKey});
  final GlobalKey cardKey;

  @override
  State<_RetainedCourse> createState() => _RetainedCourseState();
}

class _RetainedCourseState extends State<_RetainedCourse>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          child: SizedBox(
            width: 220,
            height: 140,
            child: CourseGlassSurface(
              key: widget.cardKey,
              tone: StudyTone.ink,
              child: const Center(child: Text('课程卡片')),
            ),
          ),
        ),
      ),
    );
  }
}
