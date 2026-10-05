import 'package:flutter/material.dart';
import 'homework_layout_tokens.dart';

/// Requirements and work remain visible together on a wide screen. Each pane
/// owns its scroll position; a long brief never pushes the editor offscreen.
class HomeworkWorkspace extends StatelessWidget {
  const HomeworkWorkspace({
    super.key,
    required this.identity,
    required this.header,
    required this.requirements,
    required this.work,
  });

  final String identity;
  final Widget header;
  final Widget requirements;
  final Widget work;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final wide =
          constraints.maxWidth >= 900 * scale.clamp(1, 1.4) &&
          constraints.maxHeight >= 480;
      Widget scroll(String pane, Widget child) => SingleChildScrollView(
        key: PageStorageKey('$identity-$pane'),
        primary: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 28),
        child: child,
      );
      final alignedHeader = Padding(
        padding: const EdgeInsets.symmetric(horizontal: homeworkContentInset),
        child: header,
      );
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 32 : 16,
              wide ? 28 : 12,
              wide ? 32 : 16,
              0,
            ),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            alignedHeader,
                            const SizedBox(height: 28),
                            Expanded(child: scroll('brief', requirements)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(flex: 7, child: scroll('work', work)),
                    ],
                  )
                : scroll(
                    'page',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        alignedHeader,
                        const SizedBox(height: 20),
                        requirements,
                        const SizedBox(height: 20),
                        work,
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
