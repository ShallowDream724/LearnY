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
import 'widgets/course_workbench_sheets.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _scrollController = ScrollController();
  final Map<String, Size> _cardSizes = <String, Size>{};
  final Map<String, GlobalKey> _cardKeys = <String, GlobalKey>{};
  Offset _dragAnchorOffset = Offset.zero;
  int? _activePointer;
  bool _isSaving = false;
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
        AppToast.showWarning(context, message: '当前课程信息不完整，请稍后再试');
      }
    } catch (_) {
      if (mounted) AppToast.showWarning(context, message: '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openCardMenu(ResolvedCourseCardModel card) async {
    if (_isSaving) return;
    _clearTransientDragState();
    final cards = ref.read(courseWorkbenchControllerProvider).draftCards;
    final index = cards.indexWhere((item) => item.course.id == card.course.id);
    final action = await showCourseWorkbenchMenu(
      context,
      card: card,
      canMoveEarlier: index > 0,
      canMoveLater: index >= 0 && index < cards.length - 1,
    );
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
    context.push(Routes.courseDetail(card.course.id));
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
      Rect.fromLTWH(
        globalPosition.dx - _dragAnchorOffset.dx,
        globalPosition.dy - _dragAnchorOffset.dy,
        size.width,
        size.height,
      ),
    );
  }

  void _handleGlobalPointerMove(
    PointerMoveEvent event,
    CourseWorkbenchState workbenchState,
  ) {
    if (event.pointer != _activePointer) return;
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

  void _handleGlobalPointerEnd(
    PointerEvent event,
    CourseWorkbenchState workbenchState,
  ) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
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

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _activePointer ??= event.pointer,
        onPointerMove: (event) =>
            _handleGlobalPointerMove(event, workbenchState),
        onPointerUp: (event) => _handleGlobalPointerEnd(event, workbenchState),
        onPointerCancel: (event) =>
            _handleGlobalPointerEnd(event, workbenchState),
        child: RefreshIndicator(
          onRefresh: workbenchState.isEditing ? () async {} : _handleRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
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
                          onPressed: _isSaving ? null : _handleSave,
                          child: Text(_isSaving ? '保存中' : '完成'),
                        ),
                      ]
                    : [
                        if (cardsAsync.valueOrNull?.isNotEmpty == true)
                          IconButton(
                            tooltip: '编辑课程',
                            onPressed: () =>
                                _enterEditMode(cardsAsync.valueOrNull!),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                      ],
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
        final minCardWidth = MediaQuery.textScalerOf(context).scale(170);
        final cols = ((width + 12) / (minCardWidth + 12))
            .floor()
            .clamp(1, 4)
            .toInt();
        final cardWidth = (width - (cols - 1) * 12) / cols;
        _latestFallbackCardWidth = cardWidth;
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            8,
            gutter,
            shellContentBottomInset(context),
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, rowIndex) {
              final startIndex = rowIndex * cols;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var columnIndex = 0;
                      columnIndex < cols;
                      columnIndex += 1
                    ) ...[
                      if (columnIndex > 0) const SizedBox(width: 12),
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
      },
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
    final targetKey = _cardKeys.putIfAbsent(card.course.id, GlobalKey.new);
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
            borderRadius: BorderRadius.circular(8),
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
            child: LongPressDraggable<String>(
              data: card.course.id,
              dragAnchorStrategy: (draggable, context, position) {
                final offset = childDragAnchorStrategy(
                  draggable,
                  context,
                  position,
                );
                _dragAnchorOffset = offset;
                return offset;
              },
              maxSimultaneousDrags:
                  _isSaving ||
                      (workbenchState.draggingCourseId != null && !isDragging)
                  ? 0
                  : 1,
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
        final renderBox =
            targetKey.currentContext?.findRenderObject() as RenderBox?;
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
