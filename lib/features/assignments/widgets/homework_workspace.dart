import 'package:flutter/material.dart';

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
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 12, wide ? 28 : 16, 0),
            child: wide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: scroll('brief', requirements),
                            ),
                            const SizedBox(width: 24),
                            Expanded(flex: 6, child: scroll('work', work)),
                          ],
                        ),
                      ),
                    ],
                  )
                : scroll(
                    'page',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
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
