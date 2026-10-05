import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_theme_colors.dart';
import '../design/glass_surface.dart';
import '../design/interactive_spring.dart';
import 'shell_layout_metrics.dart';
import 'shell_navigation_progress.dart';

class ShellNavDestinationData {
  const ShellNavDestinationData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.progress,
    required this.onTap,
  });
  final List<ShellNavDestinationData> destinations;
  final int selectedIndex;
  final ShellNavigationProgress progress;
  final ValueChanged<int> onTap;
  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with TickerProviderStateMixin {
  late final _position = InteractiveSpring(this, widget.progress.value);
  late final _press = InteractiveSpring(this, 0);
  late final _motion = Listenable.merge([_position, _press]);
  int? _pointer;
  VelocityTracker? _velocity;
  Offset? _down;
  bool _dragged = false;
  int? _hovered;
  int? _focused;
  int? _mouseHovered;
  bool _animationsDisabled = false;
  double _width = 1;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);
  double get _slot => (_width - 8) / widget.destinations.length;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_follow);
  }

  @override
  void didUpdateWidget(AppBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeListener(_follow);
      widget.progress.addListener(_follow);
      _follow();
    }
    if (_pointer == null && oldWidget.selectedIndex != widget.selectedIndex) {
      _follow();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = _reduceMotion;
    if (disabled && !_animationsDisabled) {
      _position.moveTo(
        _pointer == null ? widget.progress.value : _position.target,
        immediate: true,
      );
      _press.moveTo(_pointer == null ? 0 : 1, immediate: true);
    }
    _animationsDisabled = disabled;
  }

  void _follow() {
    if (_pointer != null) return;
    _position.moveTo(
      widget.progress.value,
      immediate: _reduceMotion || !widget.progress.animate,
    );
  }

  double _at(Offset point) {
    final x = Directionality.of(context) == TextDirection.rtl
        ? _width - point.dx
        : point.dx;
    final raw = (x - 4) / _slot - .5;
    final bounded = raw.clamp(0.0, widget.destinations.length - 1.0);
    final excess = raw - bounded;
    return bounded + .3 * excess / (1 + excess.abs());
  }

  int _index(double value) =>
      value.round().clamp(0, widget.destinations.length - 1);
  void _begin(PointerDownEvent event) {
    if (_pointer != null || event.buttons & kPrimaryButton == 0) return;
    _pointer = event.pointer;
    _down = event.localPosition;
    _dragged = false;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    _hovered = _index(_at(event.localPosition));
    _position.moveTo(_hovered!.toDouble(), immediate: _reduceMotion);
    _press.moveTo(1, immediate: _reduceMotion);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _velocity?.addPosition(event.timeStamp, event.localPosition);
    _dragged |= (event.localPosition.dx - _down!.dx).abs() > kTouchSlop;
    if (!_dragged) return;
    final position = _at(event.localPosition);
    final next = _index(position);
    if (next != _hovered) {
      _hovered = next;
      if (event.kind == PointerDeviceKind.touch) {
        HapticFeedback.selectionClick();
      }
    }
    _position.moveTo(position, tracking: true, immediate: _reduceMotion);
  }

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    final commit =
        event is PointerUpEvent &&
        event.localPosition.dx >= -28 &&
        event.localPosition.dx <= _width + 28 &&
        event.localPosition.dy >= -28 &&
        event.localPosition.dy <= kShellBottomNavBaseHeight + 28;
    var next = widget.selectedIndex;
    if (commit) {
      final direction = Directionality.of(context) == TextDirection.rtl
          ? -1
          : 1;
      final speed =
          (_velocity?.getVelocity().pixelsPerSecond.dx ?? 0) *
          direction /
          _slot;
      final underFinger = _index(_at(event.localPosition));
      next = _dragged
          ? _index(
              (_at(event.localPosition) + speed * .1).clamp(
                underFinger - 1.0,
                underFinger + 1.0,
              ),
            )
          : underFinger;
      if (_dragged && !_reduceMotion) _position.velocity = speed.clamp(-12, 12);
    }
    _pointer = null;
    _velocity = null;
    _down = null;
    _press.moveTo(0, immediate: _reduceMotion);
    _position.moveTo(next.toDouble(), immediate: _reduceMotion);
    if (commit && next != widget.selectedIndex) widget.onTap(next);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_follow);
    _position.dispose();
    _press.dispose();
    super.dispose();
  }

  void _activate(int index) {
    _position.moveTo(index.toDouble(), immediate: _reduceMotion);
    widget.onTap(index);
  }

  Widget _icons({required Color color}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        for (var i = 0; i < widget.destinations.length; i++)
          Expanded(
            child: Center(
              child: Icon(
                i == widget.selectedIndex
                    ? widget.destinations[i].selectedIcon
                    : widget.destinations[i].icon,
                size: 27,
                color: color,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _controls(Color foreground) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        for (var i = 0; i < widget.destinations.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == widget.selectedIndex,
              label: widget.destinations[i].label,
              onTap: () => _activate(i),
              child: Tooltip(
                message: widget.destinations[i].label,
                excludeFromSemantics: true,
                child: FocusableActionDetector(
                  mouseCursor: SystemMouseCursors.click,
                  onShowFocusHighlight: (show) => setState(() {
                    _focused = show ? i : (_focused == i ? null : _focused);
                  }),
                  onShowHoverHighlight: (show) => setState(() {
                    _mouseHovered = show
                        ? i
                        : (_mouseHovered == i ? null : _mouseHovered);
                  }),
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                  },
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        _activate(i);
                        return null;
                      },
                    ),
                  },
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: _focused == i
                          ? Border.all(color: foreground, width: 2)
                          : null,
                      color: _mouseHovered == i
                          ? foreground.withValues(alpha: .08)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final foreground = dark ? const Color(0xFFF4F5F9) : const Color(0xFF252D40);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          kShellBottomNavTopGap,
          20,
          kShellBottomNavBottomGap,
        ),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 336),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _width = constraints.maxWidth;
                final normalIcons = _icons(color: foreground);
                final lensIcons = _icons(
                  color: dark
                      ? const Color(0xFFDBE1FF)
                      : const Color(0xFF384681),
                );
                final controls = _controls(foreground);
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _begin,
                  onPointerMove: _move,
                  onPointerUp: _end,
                  onPointerCancel: _end,
                  child: SizedBox(
                    height: kShellBottomNavBaseHeight,
                    child: AnimatedBuilder(
                      animation: _motion,
                      builder: (context, _) {
                        final lift = _press.value.clamp(0.0, 1.0);
                        final stretch = _reduceMotion
                            ? 0.0
                            : (_position.velocity.abs() / 8).clamp(0.0, 1.0) *
                                  .25;
                        final centerX = 4 + _slot * (_position.value + .5);
                        final physicalX =
                            Directionality.of(context) == TextDirection.rtl
                            ? _width - centerX
                            : centerX;
                        final lens = Rect.fromCenter(
                          center: Offset(
                            physicalX,
                            kShellBottomNavBaseHeight / 2,
                          ),
                          width: (_slot - 6 + 28 * lift) * (1 + stretch),
                          height:
                              (kShellBottomNavBaseHeight - 12 + 24 * lift) *
                              (1 - stretch * .5),
                        );
                        return Transform.scale(
                          scale: 1 + (_reduceMotion ? 0 : .025 * lift),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Positioned.fill(
                                child: GlassSurface(
                                  radius: 999,
                                  optics: GlassOptics(
                                    blurSigma: 4,
                                    refraction: 9,
                                  ),
                                  child: SizedBox.expand(),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: ClipPath(
                                      clipper: _LensClip(lens, outside: true),
                                      child: normalIcons,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fromRect(
                                rect: lens,
                                child: IgnorePointer(
                                  child: GlassSurface(
                                    radius: 999,
                                    tint: dark
                                        ? Color.lerp(
                                            const Color(0x283C4560),
                                            const Color(0x64485470),
                                            lift,
                                          )
                                        : Color.lerp(
                                            const Color(0x78FFFFFF),
                                            const Color(0xB8FFFFFF),
                                            lift,
                                          ),
                                    optics: GlassOptics(
                                      blurSigma: 0,
                                      refraction: lift * 8,
                                      light: .45,
                                      shadow: .3 * lift,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: ClipPath(
                                      clipper: _LensClip(lens),
                                      child: Transform.scale(
                                        scale: 1 + .12 * lift,
                                        origin:
                                            lens.center -
                                            Offset(
                                              _width / 2,
                                              kShellBottomNavBaseHeight / 2,
                                            ),
                                        child: lensIcons,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(child: controls),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LensClip extends CustomClipper<Path> {
  const _LensClip(this.rect, {this.outside = false});
  final Rect rect;
  final bool outside;
  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    if (outside) path.addRect(Offset.zero & size);
    return path..addRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    );
  }

  @override
  bool shouldReclip(_LensClip oldClipper) =>
      oldClipper.rect != rect || oldClipper.outside != outside;
}
