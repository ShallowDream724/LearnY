import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';

import 'app_light_scene.dart';
import 'app_theme_colors.dart';
import 'material_contrast.dart';
import 'reading_feather.dart';

/// Resolves the very colors used by the child and protects that content group.
/// Features own layout and actions; this primitive owns only reading contrast.
class StudyReadingGroup extends StatelessWidget {
  const StudyReadingGroup({
    super.key,
    required this.colors,
    required this.builder,
  });
  final List<Color> colors;
  final Widget Function(BuildContext context, List<Color> inks) builder;

  @override
  Widget build(BuildContext context) {
    final inks = [
      for (final color in colors)
        readingForeground(color, dark: context.isDark),
    ];
    return StudyReadableContent(
      foregrounds: inks,
      child: builder(context, inks),
    );
  }
}

/// A convenience for one exposed label. Shrink-wrap at the layout call site
/// when the label lives in a stretched row/column.
class StudyReadableText extends StatelessWidget {
  const StudyReadableText(this.data, {super.key, this.style});
  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => StudyReadingGroup(
    colors: [
      style?.color ??
          DefaultTextStyle.of(context).style.color ??
          context.colors.text,
    ],
    builder: (_, inks) => Text(
      data,
      style: (style ?? const TextStyle()).copyWith(color: inks.single),
    ),
  );
}

/// A header may mix title text, secondary icons and primary-colored buttons.
/// Scope the actual Material defaults instead of assuming all children use
/// the title's foreground. Explicit feature colors use StudyReadingGroup.
class StudyHeaderContent extends StatelessWidget {
  const StudyHeaderContent({super.key, required this.child}) : _actions = false;
  const StudyHeaderContent.actions({super.key, required this.child})
    : _actions = true;
  final Widget child;
  final bool _actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SafeHeaderPaint(
      statusInset: StudyLightBackdrop.statusInsetOf(context),
      child: StudyReadingGroup(
        colors: _actions
            ? [theme.colorScheme.onSurfaceVariant, theme.colorScheme.primary]
            : [theme.colorScheme.onSurface],
        builder: (_, inks) {
          if (!_actions) {
            return DefaultTextStyle.merge(
              style: TextStyle(color: inks.single),
              child: IconTheme.merge(
                data: IconThemeData(color: inks.single),
                child: child,
              ),
            );
          }
          final action = WidgetStateProperty.resolveWith<Color>(
            (states) =>
                states.contains(WidgetState.disabled) ? inks[0] : inks[1],
          );
          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: inks[1],
                onSurfaceVariant: inks[0],
              ),
              textButtonTheme: TextButtonThemeData(
                style: (theme.textButtonTheme.style ?? const ButtonStyle())
                    .copyWith(foregroundColor: action),
              ),
              iconButtonTheme: IconButtonThemeData(
                style: (theme.iconButtonTheme.style ?? const ButtonStyle())
                    .copyWith(foregroundColor: WidgetStatePropertyAll(inks[0])),
              ),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: inks[0]),
              child: IconTheme.merge(
                data: IconThemeData(color: inks[0]),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SafeHeaderPaint extends SingleChildRenderObjectWidget {
  const _SafeHeaderPaint({required this.statusInset, required super.child});
  final double statusInset;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SafeHeaderBox(statusInset);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _SafeHeaderBox).statusInset = statusInset;
  }
}

class _SafeHeaderBox extends RenderProxyBox {
  _SafeHeaderBox(this._statusInset);
  double _statusInset;
  Offset _lastOrigin = Offset.zero;
  set statusInset(double value) {
    if (value == _statusInset) return;
    _statusInset = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_statusInset == 0) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final backdrop = StudyLightBackdrop.locate(
      this,
      dark: false,
      fallbackOrigin: _lastOrigin,
    );
    _lastOrigin = backdrop.origin;
    layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTRB(
        -backdrop.origin.dx,
        _statusInset - backdrop.origin.dy,
        backdrop.size.width - backdrop.origin.dx,
        backdrop.size.height - backdrop.origin.dy,
      ),
      super.paint,
      oldLayer: layer as ClipRectLayer?,
    );
  }
}

/// Protect before painting ink feedback; no borders or effects inside glyphs.
class StudyReadableContent extends StatelessWidget {
  const StudyReadableContent({
    super.key,
    required this.foregrounds,
    required this.child,
  }) : assert(foregrounds.length > 0);
  final List<Color> foregrounds;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(child: StudyLightSurface._scrim(foregrounds)),
      child,
    ],
  );
}

/// A wallpaper slice masks content passing beneath a pinned/floating header.
/// Its lower edge fades outside the toolbar instead of ending at a hard seam.
class StudyLightSurface extends LeafRenderObjectWidget {
  const StudyLightSurface({super.key}) : _foregrounds = null;
  const StudyLightSurface._scrim(this._foregrounds);
  final List<Color>? _foregrounds;

  @override
  RenderObject createRenderObject(BuildContext context) => _SceneSurfaceBox(
    StudyLightBackdrop.sceneOf(context),
    context.isDark,
    StudyLightBackdrop.motionOf(context),
    _foregrounds,
    StudyLightBackdrop.statusInsetOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _SceneSurfaceBox).update(
        StudyLightBackdrop.sceneOf(context),
        context.isDark,
        StudyLightBackdrop.motionOf(context),
        _foregrounds,
        StudyLightBackdrop.statusInsetOf(context),
      );
}

class _SceneSurfaceBox extends RenderBox {
  _SceneSurfaceBox(
    this.scene,
    this.dark,
    this.motion,
    this.foregrounds,
    this.statusInset,
  );
  List<Color>? foregrounds;
  StudyLightScene? scene;
  bool dark;
  Listenable? motion;
  double statusInset;
  Offset _lastSceneOrigin = Offset.zero;
  ReadingFeather? _feather;

  void update(
    StudyLightScene? next,
    bool nextDark,
    Listenable? nextMotion,
    List<Color>? nextForegrounds,
    double nextStatusInset,
  ) {
    if (motion != nextMotion) {
      if (attached) motion?.removeListener(markNeedsPaint);
      motion = nextMotion;
      if (attached) motion?.addListener(markNeedsPaint);
    }
    if (identical(scene, next) &&
        dark == nextDark &&
        listEquals(foregrounds, nextForegrounds) &&
        statusInset == nextStatusInset) {
      return;
    }
    scene = next;
    dark = nextDark;
    foregrounds = nextForegrounds;
    statusInset = nextStatusInset;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    motion?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    motion?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
  @override
  Rect get paintBounds => (Offset.zero & size).inflate(ReadingFeather.extent);

  @override
  void paint(PaintingContext context, Offset offset) {
    final backdrop = StudyLightBackdrop.locate(
      this,
      dark: dark,
      fallbackOrigin: _lastSceneOrigin,
    );
    _lastSceneOrigin = backdrop.origin;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(
      offset.dx - backdrop.origin.dx,
      offset.dy - backdrop.origin.dy,
    );
    final coverage = backdrop.origin & size;
    final inks = foregrounds;
    if (inks == null) {
      // One bounded compositing layer for an overlapping toolbar, never for
      // repeated labels. Compose the wallpaper before applying its edge mask
      // so strength < 100% cannot produce a differently tinted seam.
      final extended = Rect.fromLTRB(
        coverage.left,
        coverage.top,
        coverage.right,
        coverage.bottom + ReadingFeather.extent,
      );
      canvas.saveLayer(extended, Paint());
      backdrop.scene.paint(canvas, backdrop.size, coverage: extended);
      canvas.drawRect(
        extended,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader =
              const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Color(0xD7FFFFFF),
                  Color(0x80FFFFFF),
                  Color(0x28FFFFFF),
                  Colors.transparent,
                ],
                stops: [0, .25, .5, .75, 1],
              ).createShader(
                Rect.fromLTRB(
                  coverage.left,
                  coverage.bottom,
                  coverage.right,
                  extended.bottom,
                ),
              ),
      );
      canvas.restore();
    } else {
      var alpha = 0.0;
      for (final ink in inks) {
        final needed = backdrop.scene.readingOpacity(
          coverage,
          backdrop.size,
          minimum: 0,
          foreground: ink,
        );
        if (needed > alpha) alpha = needed;
      }
      if (alpha > 0) {
        final color = (dark ? const Color(0xFF20242D) : Colors.white)
            .withValues(alpha: alpha);
        if (_feather?.color != color) _feather = ReadingFeather(color);
        _feather!.paint(
          canvas,
          coverage,
          topExtent: (coverage.top - statusInset).clamp(
            0.0,
            ReadingFeather.extent,
          ),
        );
      }
    }
    canvas.restore();
  }
}
