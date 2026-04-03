import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/action_sheet.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/responsive.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/providers/sync_models.dart';
import '../../core/router/router.dart';
import '../../core/shell/shell_layout_metrics.dart';
import '../../core/sync/sync_actions.dart';
import 'providers/course_workbench_controller.dart';
import 'providers/course_workbench_models.dart';
import 'providers/course_workbench_repository.dart';
import 'widgets/course_card_tile.dart';
import 'widgets/course_drag_auto_scroller.dart';
import 'widgets/course_workbench_sheets.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _scrollController = ScrollController();
  final Map<String, Size> _cardSizes = <String, Size>{};
  late final CourseDragAutoScroller _dragAutoScroller;
  double _latestFallbackCardWidth = 160;

  @override
  void initState() {
    super.initState();
    _dragAutoScroller = CourseDragAutoScroller(
      scrollController: _scrollController,
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
    if (!workbenchState.isEditing) {
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
      if (confirmed != true) {
        return;
      }
    }

    _clearTransientDragState(clearWorkbenchState: false);
    await _workbenchController.cancelEditing(force: true);
  }

  Future<void> _handleSave() async {
    _clearTransientDragState(clearWorkbenchState: false);
    final success = await _workbenchController.save();
    if (!mounted) {
      return;
    }
    if (success) {
      AppToast.showSuccess(context, message: '课程工作台已更新');
    } else {
      AppToast.showWarning(context, message: '当前课程信息不完整，请稍后再试');
    }
  }

  Future<void> _openCardMenu(ResolvedCourseCardModel card) async {
    _clearTransientDragState();
    final action = await showCourseWorkbenchMenu(context, card: card);
    if (!mounted || action == null) {
      return;
    }

    final controller = _workbenchController;
    switch (action) {
      case CourseWorkbenchMenuAction.chooseIcon:
        final result = await showCourseIconPickerSheet(
          context,
          selectedIconKey: card.iconKey,
        );
        if (!mounted || result == null || !result.submitted) {
          return;
        }
        controller.updateIcon(card.course.id, result.iconKey);
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
    }
  }

  void _enterEditMode(List<ResolvedCourseCardModel> cards) {
    if (cards.isEmpty) {
      return;
    }
    _clearTransientDragState(clearWorkbenchState: false);
    HapticFeedback.selectionClick();
    _workbenchController.beginEditing(cards);
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
    context.go(Routes.courseDetail(card.course.id));
  }

  void _handleBrowseLongPress(
    ResolvedCourseCardModel card,
    List<ResolvedCourseCardModel> cards,
  ) {
    _enterEditMode(cards);
  }

  void _updateAutoScrollForCourse({
    required String courseId,
    required Offset globalPosition,
    required double fallbackWidth,
  }) {
    final size = _cardSizes[courseId] ?? Size(fallbackWidth, 184);
    _dragAutoScroller.updateDragRect(
      Rect.fromCenter(
        center: globalPosition,
        width: size.width,
        height: size.height,
      ),
    );
  }

  void _handleGlobalPointerMove(
    PointerMoveEvent event,
    CourseWorkbenchState workbenchState,
  ) {
    final courseId = workbenchState.draggingCourseId;
    if (courseId == null) {
      return;
    }
    _updateAutoScrollForCourse(
      courseId: courseId,
      globalPosition: event.position,
      fallbackWidth: _latestFallbackCardWidth,
    );
  }

  void _handleGlobalPointerEnd(CourseWorkbenchState workbenchState) {
    if (workbenchState.draggingCourseId == null) {
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
    _latestFallbackCardWidth = _estimateCardWidth(
      context,
      courseGridColumns(context),
    );

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (event) =>
            _handleGlobalPointerMove(event, workbenchState),
        onPointerUp: (_) => _handleGlobalPointerEnd(workbenchState),
        onPointerCancel: (_) => _handleGlobalPointerEnd(workbenchState),
        child: RefreshIndicator(
          onRefresh: workbenchState.isEditing ? () async {} : _handleRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                leading: workbenchState.isEditing
                    ? TextButton(
                        onPressed: () => _handleCancel(workbenchState),
                        child: const Text('取消'),
                      )
                    : null,
                leadingWidth: workbenchState.isEditing ? 68 : null,
                title: Text(
                  workbenchState.isEditing ? '编辑课程' : '课程',
                  style: AppTypography.headlineMedium.copyWith(color: c.text),
                ),
                actions: workbenchState.isEditing
                    ? [
                        PopupMenuButton<String>(
                          tooltip: '更多',
                          onSelected: (value) {
                            if (value == 'reset-order') {
                              ref
                                  .read(
                                    courseWorkbenchControllerProvider.notifier,
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
                          onPressed: _handleSave,
                          child: const Text('完成'),
                        ),
                      ]
                    : [
                        if (cardsAsync.valueOrNull?.isNotEmpty == true)
                          TextButton(
                            onPressed: () =>
                                _enterEditMode(cardsAsync.valueOrNull!),
                            child: const Text('编辑'),
                          ),
                      ],
              ),
              if (workbenchState.isEditing)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            size: 18,
                            color: c.subtitle,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '长按拖动排序，轻点课程卡可更换图标或设置简称。',
                              style: AppTypography.bodySmall.copyWith(
                                color: c.subtitle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              cardsAsync.when(
                loading: () => const SliverFillRemaining(child: ListSkeleton()),
                error: (error, _) => _buildError(c),
                data: (cards) {
                  final displayCards = workbenchState.isEditing
                      ? workbenchState.draftCards
                      : cards;
                  if (displayCards.isEmpty) {
                    return _buildEmpty(c);
                  }

                  return _buildGridSliver(context, displayCards, workbenchState);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverFillRemaining _buildError(AppThemeColors c) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: c.subtitle),
            const SizedBox(height: 12),
            Text(
              '加载失败',
              style: AppTypography.titleMedium.copyWith(color: c.text),
            ),
            const SizedBox(height: 8),
            Text(
              '请下拉刷新重试',
              style: AppTypography.bodySmall.copyWith(color: c.tertiary),
            ),
          ],
        ),
      ),
    );
  }

  SliverFillRemaining _buildEmpty(AppThemeColors c) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 48, color: c.tertiary),
            const SizedBox(height: 12),
            Text(
              '暂无课程',
              style: AppTypography.titleMedium.copyWith(color: c.tertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSliver(
    BuildContext context,
    List<ResolvedCourseCardModel> cards,
    CourseWorkbenchState workbenchState,
  ) {
    final cols = courseGridColumns(context);
    final controller = ref.read(courseWorkbenchControllerProvider.notifier);
    final cardWidth = _estimateCardWidth(context, cols);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, shellContentBottomInset(context)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, rowIndex) {
          final startIndex = rowIndex * cols;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var columnIndex = 0;
                  columnIndex < cols;
                  columnIndex += 1
                ) ...[
                  if (columnIndex > 0) const SizedBox(width: 10),
                  if (startIndex + columnIndex < cards.length)
                    Expanded(
                      child: _buildGridCardCell(
                        localContext: context,
                        card: cards[startIndex + columnIndex],
                        allCards: cards,
                        cardIndex: startIndex + columnIndex,
                        columns: cols,
                        workbenchState: workbenchState,
                        controller: controller,
                        feedbackWidth: cardWidth,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                ],
              ],
            ),
          );
        }, childCount: (cards.length + cols - 1) ~/ cols),
      ),
    );
  }

  Widget _buildGridCardCell({
    required BuildContext localContext,
    required ResolvedCourseCardModel card,
    required List<ResolvedCourseCardModel> allCards,
    required int cardIndex,
    required int columns,
    required CourseWorkbenchState workbenchState,
    required CourseWorkbenchController controller,
    required double feedbackWidth,
  }) {
    _attachDragAutoScroller(localContext);
    final isDragging = workbenchState.draggingCourseId == card.course.id;
    final isHoverTarget = workbenchState.hoverCourseId == card.course.id;
    final colorIndex = _stableColorIndex(card.course.id);
    final baseCard = _MeasureCardSize(
      onSizeChanged: (size) {
        _cardSizes[card.course.id] = size;
      },
      child: CourseCardTile(
        key: ValueKey('course-card-${card.course.id}'),
        card: card,
        colorIndex: colorIndex,
        isEditing: workbenchState.isEditing,
        onTap: () => _handleCardTap(card, workbenchState.isEditing, allCards),
        onLongPress: workbenchState.isEditing
            ? null
            : () => _handleBrowseLongPress(card, allCards),
      ),
    );
    final cardWidget = _AnimatedDragCard(
      isDragging: isDragging,
      child: baseCard,
    );

    if (!workbenchState.isEditing) {
      return cardWidget
          .animate(delay: (60 * cardIndex).ms)
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != card.course.id,
      onAcceptWithDetails: (_) {
        _handleDragFinished(controller);
        HapticFeedback.selectionClick();
      },
      builder: (context, candidateData, _) {
        final isTargeted = candidateData.isNotEmpty;
        return AnimatedContainer(
          key: ValueKey('course-cell-${card.course.id}'),
          duration: const Duration(milliseconds: 140),
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
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            scale: isHoverTarget && !isDragging ? 0.985 : 1,
            child: LongPressDraggable<String>(
              data: card.course.id,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: SizedBox(
                width: feedbackWidth,
                child: Material(
                  color: Colors.transparent,
                  child: CourseCardTile(
                    card: card,
                    colorIndex: colorIndex,
                    isEditing: true,
                    onTap: () {},
                  ),
                ),
              ),
              childWhenDragging: _DragPlaceholderCard(
                card: card,
                colorIndex: colorIndex,
              ),
              onDragStarted: () =>
                  _handleDragStarted(card.course.id, controller),
              onDragCompleted: () => _handleDragFinished(controller),
              onDragEnd: (_) => _handleDragFinished(controller),
              child: cardWidget,
            ),
          ),
        );
      },
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          return;
        }
        final localPosition = renderBox.globalToLocal(details.offset);
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

  double _estimateCardWidth(BuildContext context, int cols) {
    final totalWidth = MediaQuery.sizeOf(context).width;
    const horizontalPadding = 32.0;
    const gap = 10.0;
    final availableWidth = totalWidth - horizontalPadding - (cols - 1) * gap;
    return availableWidth / cols;
  }

  int _stableColorIndex(String courseId) {
    var hash = 0;
    for (final unit in courseId.codeUnits) {
      hash = 0x1fffffff & (hash * 37 + unit);
    }
    return hash;
  }
}

class _DragPlaceholderCard extends StatelessWidget {
  const _DragPlaceholderCard({required this.card, required this.colorIndex});

  final ResolvedCourseCardModel card;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Visibility(
        visible: false,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: CourseCardTile(
          card: card,
          colorIndex: colorIndex,
          isEditing: true,
          onTap: () {},
        ),
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
      duration: const Duration(milliseconds: 120),
      opacity: isDragging ? 0.3 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: isDragging ? 0.985 : 1,
        child: child,
      ),
    );
  }
}

class _MeasureCardSize extends StatefulWidget {
  const _MeasureCardSize({required this.onSizeChanged, required this.child});

  final ValueChanged<Size> onSizeChanged;
  final Widget child;

  @override
  State<_MeasureCardSize> createState() => _MeasureCardSizeState();
}

class _MeasureCardSizeState extends State<_MeasureCardSize> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderBox = context.findRenderObject() as RenderBox?;
      final size = renderBox?.size;
      if (size == null || size == _lastSize) {
        return;
      }
      _lastSize = size;
      widget.onSizeChanged(size);
    });
    return widget.child;
  }
}
