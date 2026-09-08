import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/action_sheet.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/course_glass.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/providers/sync_models.dart';
import '../../core/router/router.dart';
import '../../core/semester/semester_switcher.dart';
import '../../core/shell/shell_layout_metrics.dart';
import '../../core/sync/sync_actions.dart';
import 'providers/course_workbench_controller.dart';
import 'providers/course_workbench_models.dart';
import 'providers/course_workbench_repository.dart';
import 'widgets/course_card_tile.dart';
import 'widgets/course_drag_auto_scroller.dart';
import 'widgets/course_drag_source.dart';
import 'widgets/course_grid_layout.dart';
import 'widgets/course_workbench_sheets.dart';

typedef _CourseExtentSignature = ({
  String title,
  String secondaryLabel,
  int pendingHomeworks,
  int unreadNotifications,
  int totalFiles,
  double width,
  TextScaler textScaler,
  TextDirection textDirection,
  bool isEditing,
  String fontFamily,
});

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};
  final _cardExtents =
      <String, ({_CourseExtentSignature signature, double extent})>{};
  Offset _dragAnchorOffset = Offset.zero;
  Size _dragSize = Size.zero;
  Offset? _dragPosition;
  int _columns = 1;
  bool _reorderScheduled = false;
  int? _activePointer;
  bool _isSaving = false;
  late final CourseDragAutoScroller _dragAutoScroller;

  @override
  void initState() {
    super.initState();
    _dragAutoScroller = CourseDragAutoScroller(
      scrollController: _scrollController,
      onScrolled: _reorderAfterScroll,
    );
  }

  @override
  void dispose() {
    _dragAutoScroller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  CourseWorkbenchController get _workbenchController =>
      ref.read(courseWorkbenchControllerProvider.notifier);

  Future<void> _handleRefresh() async {
    final ss = (await ref.read(syncActionsProvider).refreshAll()).state;
    if (ss.status == SyncStatus.cooldown && mounted) {
      CooldownToast.show(context, seconds: ss.cooldownSeconds);
    }
  }

  Future<void> _handleCancel(CourseWorkbenchState workbenchState) async {
    if (!workbenchState.isEditing || _isSaving) {
      return;
    }

    if (workbenchState.hasChanges) {
      final confirmed = await AppActionSheet.show(
        context,
        title: '放弃当前课程编排？',
        subtitle: '未保存的顺序、图标和简称修改会丢失。',
        confirmLabel: '放弃修改',
        confirmColor: AppColors.error,
      );
      if (!mounted || confirmed != true) {
        return;
      }
    }

    _clearTransientDragState(clearWorkbenchState: false);
    await _workbenchController.cancelEditing(force: true);
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    _clearTransientDragState(clearWorkbenchState: false);
    try {
      final success = await _workbenchController.save();
      if (!mounted) return;
      if (success) {
        AppToast.showSuccess(context, message: '课程已更新');
      } else {
        AppToast.showWarning(context, message: '课程或学期已变化，请退出整理后重试');
      }
    } catch (_) {
      if (mounted) AppToast.showWarning(context, message: '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openCardMenu(
    ResolvedCourseCardModel card, [
    Rect? anchor,
  ]) async {
    if (_isSaving) return;
    _clearTransientDragState();
    final state = ref.read(courseWorkbenchControllerProvider);
    final cards = state.isEditing
        ? state.draftCards
        : ref.read(resolvedCourseCardsProvider).valueOrNull ??
              const <ResolvedCourseCardModel>[];
    final index = cards.indexWhere((item) => item.course.id == card.course.id);
    final action = await showCourseWorkbenchMenu(
      context,
      card: card,
      anchor: anchor ?? _cardBounds(card.course.id) ?? Rect.zero,
      canMoveEarlier: index > 0,
      canMoveLater: index >= 0 && index < cards.length - 1,
    );
    if (!mounted || action == null) {
      return;
    }
    if (!ref.read(courseWorkbenchControllerProvider).isEditing) {
      _enterEditMode(cards);
    }

    final controller = _workbenchController;
    switch (action) {
      case CourseWorkbenchMenuAction.chooseIcon:
        await _chooseCardIcon(card);
        break;
      case CourseWorkbenchMenuAction.editAlias:
        final result = await showCourseAliasEditorSheet(context, card: card);
        if (!mounted || result == null || !result.submitted) {
          return;
        }
        controller.updateAlias(card.course.id, result.alias);
        break;
      case CourseWorkbenchMenuAction.restoreDefault:
        controller.restoreCourseCustomization(card.course.id);
        if (mounted) {
          AppToast.showInfo(context, message: '已恢复默认图标和简称');
        }
        break;
      case CourseWorkbenchMenuAction.moveEarlier:
      case CourseWorkbenchMenuAction.moveLater:
        final currentCards = ref
            .read(courseWorkbenchControllerProvider)
            .draftCards;
        final current = currentCards.indexWhere(
          (item) => item.course.id == card.course.id,
        );
        final target =
            current +
            (action == CourseWorkbenchMenuAction.moveEarlier ? -1 : 1);
        if (current >= 0 && target >= 0 && target < currentCards.length) {
          controller.previewReorder(
            draggedCourseId: card.course.id,
            targetCourseId: currentCards[target].course.id,
            insertIndex: target > current ? target + 1 : target,
          );
          controller.completeDragging();
        }
        break;
    }
  }

  Future<void> _chooseCardIcon(ResolvedCourseCardModel card) async {
    if (_isSaving) return;
    _clearTransientDragState();
    final result = await showCourseIconPickerSheet(
      context,
      selectedIconKey: card.iconKey,
      courseName: card.course.name,
      courseId: card.course.id,
    );
    if (!mounted || result == null || !result.submitted) return;
    _workbenchController.updateIcon(card.course.id, result.iconKey);
  }

  void _enterEditMode(List<ResolvedCourseCardModel> cards) {
    if (cards.isEmpty) {
      return;
    }
    _clearTransientDragState(clearWorkbenchState: false);
    HapticFeedback.selectionClick();
    _workbenchController.beginEditing(
      cards,
      scope: ref.read(courseWorkbenchScopeProvider),
    );
  }

  void _handleCardTap(
    ResolvedCourseCardModel card,
    bool isEditing,
    List<ResolvedCourseCardModel> sourceCards,
  ) {
    if (isEditing) {
      _openCardMenu(card);
      return;
    }
    context.push(Routes.courseDetail(card.course.id));
  }

  void _handleBrowseLongPress(
    ResolvedCourseCardModel card,
    List<ResolvedCourseCardModel> cards,
  ) {
    _enterEditMode(cards);
  }

  void _handleGlobalPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    if (ref.read(courseWorkbenchControllerProvider).draggingCourseId == null) {
      return;
    }
    _dragPosition = event.position;
    _dragAutoScroller.updateDragRect(
      (event.position - _dragAnchorOffset) & _dragSize,
    );
  }

  Rect? _cardBounds(String courseId) {
    final box = _cardKeys[courseId]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // Auto-scroll changes the target under a stationary pointer.
  void _reorderAfterScroll() {
    if (_reorderScheduled || !mounted) return;
    _reorderScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reorderScheduled = false;
      _reorderAtPointer();
    });
  }

  void _reorderAtPointer() {
    if (!mounted || _dragPosition == null) return;
    final state = ref.read(courseWorkbenchControllerProvider);
    final dragged = state.draggingCourseId;
    if (dragged == null) return;
    for (var index = 0; index < state.draftCards.length; index++) {
      final id = state.draftCards[index].course.id;
      final bounds = _cardBounds(id);
      if (id == dragged || bounds == null || !bounds.contains(_dragPosition!)) {
        continue;
      }
      _workbenchController.previewReorder(
        draggedCourseId: dragged,
        targetCourseId: id,
        insertIndex: _resolvePreviewInsertIndex(
          localPosition: _dragPosition! - bounds.topLeft,
          targetIndex: index,
          targetSize: bounds.size,
          columns: _columns,
        ),
      );
      break;
    }
  }

  void _handleGlobalPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    if (ref.read(courseWorkbenchControllerProvider).draggingCourseId == null) {
      return;
    }
    _clearTransientDragState();
  }

  void _handleDragStarted(
    String courseId,
    CourseWorkbenchController controller,
  ) {
    _clearTransientDragState(clearWorkbenchState: false);
    HapticFeedback.mediumImpact();
    controller.startDragging(courseId);
  }

  void _handleDragFinished(CourseWorkbenchController controller) {
    _clearTransientDragState(clearWorkbenchState: false);
    controller.completeDragging();
  }

  void _clearTransientDragState({bool clearWorkbenchState = true}) {
    _dragAutoScroller.stop();
    _dragPosition = null;
    if (clearWorkbenchState) {
      _workbenchController.completeDragging();
    }
  }

  void _attachDragAutoScroller(BuildContext localContext) {
    final scrollable = Scrollable.maybeOf(localContext, axis: Axis.vertical);
    if (scrollable == null) {
      _dragAutoScroller.stop();
      return;
    }

    _dragAutoScroller.attach(
      scrollable,
      viewportObstruction: EdgeInsets.only(
        bottom: shellBottomNavBarHeight(localContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cardsAsync = ref.watch(resolvedCourseCardsProvider);
    final workbenchState = ref.watch(courseWorkbenchControllerProvider);

    return Scaffold(
      body: CourseGlassBackdrop(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _activePointer ??= event.pointer,
          onPointerMove: _handleGlobalPointerMove,
          onPointerUp: _handleGlobalPointerEnd,
          onPointerCancel: _handleGlobalPointerEnd,
          child: RefreshIndicator(
            onRefresh: workbenchState.isEditing ? () async {} : _handleRefresh,
            color: context.colors.infoAccent,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: semesterToolbarHeight(context),
                  titleSpacing: pageGutter(context),
                  floating: true,
                  snap: true,
                  leading: workbenchState.isEditing
                      ? TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => _handleCancel(workbenchState),
                          child: const Text('取消'),
                        )
                      : null,
                  leadingWidth: workbenchState.isEditing ? 68 : null,
                  title: workbenchState.isEditing
                      ? Text(
                          '编辑课程',
                          style: AppTypography.headlineMedium.copyWith(
                            color: c.text,
                          ),
                        )
                      : const SemesterPageTitle(title: '课程'),
                  actions: workbenchState.isEditing
                      ? [
                          PopupMenuButton<String>(
                            enabled: !_isSaving,
                            tooltip: '更多',
                            onSelected: (value) {
                              if (value == 'reset-order') {
                                ref
                                    .read(
                                      courseWorkbenchControllerProvider
                                          .notifier,
                                    )
                                    .restoreDefaultOrder();
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'reset-order',
                                child: Text('恢复默认排序'),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _isSaving ? null : _handleSave,
                            child: Text(_isSaving ? '保存中' : '完成'),
                          ),
                        ]
                      : [
                          if (cardsAsync.valueOrNull?.isNotEmpty == true)
                            Tooltip(
                              message: '编辑课程',
                              child: TextButton(
                                onPressed: () =>
                                    _enterEditMode(cardsAsync.valueOrNull!),
                                child: const Text('整理课程'),
                              ),
                            ),
                        ],
                ),
                cardsAsync.when(
                  loading: () =>
                      const SliverFillRemaining(child: ListSkeleton()),
                  error: (error, _) => _buildError(c),
                  data: (cards) {
                    final displayCards = workbenchState.isEditing
                        ? workbenchState.draftCards
                        : cards;
                    if (displayCards.isEmpty) {
                      _cardKeys.clear();
                      _cardExtents.clear();
                      return _buildEmpty(c);
                    }

                    return _buildGridSliver(
                      context,
                      displayCards,
                      workbenchState,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverFillRemaining _buildError(AppThemeColors c) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: '课程加载失败',
        action: OutlinedButton.icon(
          onPressed: _handleRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      ),
    );
  }

  SliverFillRemaining _buildEmpty(AppThemeColors c) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: const AppEmptyState(icon: Icons.school_outlined, title: '本学期暂无课程'),
    );
  }

  Widget _buildGridSliver(
    BuildContext context,
    List<ResolvedCourseCardModel> cards,
    CourseWorkbenchState workbenchState,
  ) {
    final controller = ref.read(courseWorkbenchControllerProvider.notifier);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final gutter = pageGutterForWidth(constraints.crossAxisExtent);
        final width = constraints.crossAxisExtent - gutter * 2;
        final minCardWidth = MediaQuery.textScalerOf(
          context,
        ).scale(constraints.crossAxisExtent < 600 ? 170 : 230);
        final cols = ((width + 12) / (minCardWidth + 12))
            .floor()
            .clamp(1, 4)
            .toInt();
        final cardWidth = (width - (cols - 1) * 12) / cols;
        final rowExtents = List<double>.filled((cards.length / cols).ceil(), 0);
        for (var index = 0; index < cards.length; index++) {
          final extent = _cardExtent(
            context,
            card: cards[index],
            width: cardWidth,
            isEditing: workbenchState.isEditing,
          );
          rowExtents[index ~/ cols] = math.max(
            rowExtents[index ~/ cols],
            extent,
          );
        }
        final indices = {
          for (var index = 0; index < cards.length; index++)
            cards[index].course.id: index,
        };
        _cardKeys.removeWhere((id, _) => !indices.containsKey(id));
        _cardExtents.removeWhere((id, _) => !indices.containsKey(id));
        _columns = cols;
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            8,
            gutter,
            shellContentBottomInset(context),
          ),
          sliver: SliverGrid.builder(
            // The glass samples the viewport at paint time while scrolling.
            // Individual glyphs retain their own small repaint boundaries.
            addRepaintBoundaries: false,
            gridDelegate: CourseGridDelegate(
              columns: cols,
              cardWidth: cardWidth,
              rowExtents: rowExtents,
            ),
            itemCount: cards.length,
            findChildIndexCallback: (key) =>
                indices[(key as ValueKey<String>).value],
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey(cards[index].course.id),
              child: _buildGridCardCell(
                localContext: context,
                card: cards[index],
                allCards: cards,
                cardIndex: index,
                columns: cols,
                workbenchState: workbenchState,
                controller: controller,
                feedbackSize: Size(cardWidth, rowExtents[index ~/ cols]),
              ),
            ),
          ),
        );
      },
    );
  }

  double _cardExtent(
    BuildContext context, {
    required ResolvedCourseCardModel card,
    required double width,
    required bool isEditing,
  }) {
    final signature = (
      title: card.displayTitle,
      secondaryLabel: card.secondaryLabel,
      pendingHomeworks: card.pendingHomeworks,
      unreadNotifications: card.unreadNotifications,
      totalFiles: card.totalFiles,
      width: width,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      isEditing: isEditing,
      fontFamily: AppTypography.fontFamily,
    );
    final cached = _cardExtents[card.course.id];
    if (cached?.signature == signature) return cached!.extent;

    final extent = CourseCardTile.gridExtent(
      context,
      card: card,
      width: width,
      isEditing: isEditing,
    );
    _cardExtents[card.course.id] = (signature: signature, extent: extent);
    return extent;
  }

  Widget _buildGridCardCell({
    required BuildContext localContext,
    required ResolvedCourseCardModel card,
    required List<ResolvedCourseCardModel> allCards,
    required int cardIndex,
    required int columns,
    required CourseWorkbenchState workbenchState,
    required CourseWorkbenchController controller,
    required Size feedbackSize,
  }) {
    _attachDragAutoScroller(localContext);
    final isDragging = workbenchState.draggingCourseId == card.course.id;
    final isHoverTarget = workbenchState.hoverCourseId == card.course.id;
    final targetKey = _cardKeys.putIfAbsent(card.course.id, GlobalKey.new);
    final baseCard = CourseCardTile(
      key: ValueKey('course-card-${card.course.id}'),
      card: card,
      isEditing: workbenchState.isEditing,
      onTap: () => _handleCardTap(card, workbenchState.isEditing, allCards),
      onMenu: (anchor) => _openCardMenu(card, anchor),
      onChooseIcon: () => _chooseCardIcon(card),
      onLongPress: workbenchState.isEditing
          ? null
          : () => _handleBrowseLongPress(card, allCards),
    );
    final cardWidget = _AnimatedDragCard(
      isDragging: isDragging,
      child: baseCard,
    );

    if (!workbenchState.isEditing) {
      return cardWidget;
    }

    return DragTarget<String>(
      key: targetKey,
      onWillAcceptWithDetails: (details) => details.data != card.course.id,
      onAcceptWithDetails: (_) {
        _handleDragFinished(controller);
        HapticFeedback.selectionClick();
      },
      builder: (context, candidateData, _) {
        final isTargeted = candidateData.isNotEmpty;
        return AnimatedContainer(
          key: ValueKey('course-cell-${card.course.id}'),
          duration: AppMotion.duration(context, AppMotion.feedback),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: isTargeted
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(24),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: AnimatedScale(
            duration: AppMotion.duration(context, AppMotion.feedback),
            curve: Curves.easeOutCubic,
            scale: isHoverTarget && !isDragging ? 0.985 : 1,
            child: CourseDragSource(
              courseId: card.course.id,
              anchorStrategy: (draggable, context, position) {
                final offset = childDragAnchorStrategy(
                  draggable,
                  context,
                  position,
                );
                _dragAnchorOffset = offset;
                _dragSize = (context.findRenderObject()! as RenderBox).size;
                return offset;
              },
              enabled:
                  !_isSaving &&
                  (workbenchState.draggingCourseId == null || isDragging),
              feedback: SizedBox(
                width: feedbackSize.width,
                height: feedbackSize.height,
                child: Material(
                  color: Colors.transparent,
                  child: CourseCardTile(
                    card: card,
                    isEditing: true,
                    onTap: () {},
                  ),
                ),
              ),
              placeholder: _DragPlaceholderCard(card: card),
              onStarted: () => _handleDragStarted(card.course.id, controller),
              onFinished: () => _handleDragFinished(controller),
              child: cardWidget,
            ),
          ),
        );
      },
      onMove: (details) {
        final renderBox =
            targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          return;
        }
        final localPosition = renderBox.globalToLocal(
          details.offset + _dragAnchorOffset,
        );
        controller.previewReorder(
          draggedCourseId: details.data,
          targetCourseId: card.course.id,
          insertIndex: _resolvePreviewInsertIndex(
            localPosition: localPosition,
            targetIndex: cardIndex,
            targetSize: renderBox.size,
            columns: columns,
          ),
        );
      },
    );
  }

  int _resolvePreviewInsertIndex({
    required Offset localPosition,
    required int targetIndex,
    required Size targetSize,
    required int columns,
  }) {
    if (columns <= 1) {
      return localPosition.dy < targetSize.height / 2
          ? targetIndex
          : targetIndex + 1;
    }
    return localPosition.dx < targetSize.width / 2
        ? targetIndex
        : targetIndex + 1;
  }
}

class _DragPlaceholderCard extends StatelessWidget {
  const _DragPlaceholderCard({required this.card});

  final ResolvedCourseCardModel card;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Visibility(
        visible: false,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: CourseCardTile(card: card, isEditing: true, onTap: () {}),
      ),
    );
  }
}

class _AnimatedDragCard extends StatelessWidget {
  const _AnimatedDragCard({required this.isDragging, required this.child});

  final bool isDragging;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.duration(context, AppMotion.feedback),
      opacity: isDragging ? 0.3 : 1,
      child: AnimatedScale(
        duration: AppMotion.duration(context, AppMotion.feedback),
        curve: Curves.easeOutCubic,
        scale: isDragging ? 0.985 : 1,
        child: child,
      ),
    );
  }
}
