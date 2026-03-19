import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 可拖拽调整大小的分隔线
///
/// 用于在两个面板之间提供可拖拽的分隔线，允许用户调整面板宽度
class ResizableDivider extends StatefulWidget {
  /// 分隔线宽度（可拖拽区域宽度）
  final double width;

  /// 分隔线颜色
  final Color? color;

  /// 悬停时的分隔线颜色
  final Color? hoverColor;

  /// 拖拽时的分隔线颜色
  final Color? activeColor;

  /// 分隔线粗细（视觉上的线条宽度）
  final double thickness;

  /// 拖拽时的回调，参数为拖拽的 delta（水平移动距离）
  final ValueChanged<double> onDrag;

  /// 拖拽开始时的回调
  final VoidCallback? onDragStart;

  /// 拖拽结束时的回调
  final VoidCallback? onDragEnd;

  /// 是否垂直（true 为垂直分隔线，false 为水平分隔线）
  final bool vertical;

  const ResizableDivider({
    super.key,
    this.width = 12,
    this.color,
    this.hoverColor,
    this.activeColor,
    this.thickness = 1,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.vertical = true,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultColor = widget.color ?? theme.dividerColor.withValues(alpha: 0);
    final defaultHoverColor =
        widget.hoverColor ?? theme.colorScheme.primary.withValues(alpha: 0.5);
    final defaultActiveColor =
        widget.activeColor ?? theme.colorScheme.primary;

    Color currentColor;
    if (_isDragging) {
      currentColor = defaultActiveColor;
    } else if (_isHovering) {
      currentColor = defaultHoverColor;
    } else {
      currentColor = defaultColor;
    }

    return MouseRegion(
      cursor: widget.vertical
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
          widget.onDragStart?.call();
        },
        onHorizontalDragUpdate: (details) {
          widget.onDrag(details.delta.dx);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        child: Container(
          width: widget.vertical ? widget.width : null,
          height: widget.vertical ? null : widget.width,
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: widget.vertical ? widget.thickness : null,
              height: widget.vertical ? null : widget.thickness,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(widget.thickness / 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 用于包裹可调整大小面板的 Widget
///
/// 自动处理拖拽逻辑并约束面板宽度
class ResizablePanel extends ConsumerWidget {
  /// 面板的初始宽度
  final double initialWidth;

  /// 面板的最小宽度
  final double minWidth;

  /// 面板的最大宽度（相对于父容器宽度的比例）
  final double maxWidthRatio;

  /// 面板内容构建器
  final Widget Function(BuildContext context, double width) builder;

  /// 状态提供者
  final StateProvider<double> widthProvider;

  const ResizablePanel({
    super.key,
    required this.initialWidth,
    required this.widthProvider,
    this.minWidth = 280,
    this.maxWidthRatio = 0.5,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = ref.watch(widthProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * maxWidthRatio;
        final clampedWidth = width.clamp(minWidth, maxWidth);

        return SizedBox(
          width: clampedWidth,
          child: builder(context, clampedWidth),
        );
      },
    );
  }
}

/// 带拖拽分隔线的双面板布局
class ResizableSplitLayout extends ConsumerStatefulWidget {
  /// 左/上面板
  final Widget firstPanel;

  /// 右/下面板
  final Widget secondPanel;

  /// 第二面板的初始宽度
  final double initialSecondWidth;

  /// 第二面板的最小宽度
  final double minSecondWidth;

  /// 第二面板的最大宽度比例
  final double maxSecondWidthRatio;

  /// 宽度状态提供者
  final StateProvider<double> widthProvider;

  /// 是否垂直布局（true 为左右布局，false 为上下布局）
  final bool vertical;

  /// 分隔线配置
  final double dividerWidth;
  final double dividerThickness;

  const ResizableSplitLayout({
    super.key,
    required this.firstPanel,
    required this.secondPanel,
    required this.initialSecondWidth,
    required this.widthProvider,
    this.minSecondWidth = 280,
    this.maxSecondWidthRatio = 0.5,
    this.vertical = true,
    this.dividerWidth = 12,
    this.dividerThickness = 1,
  });

  @override
  ConsumerState<ResizableSplitLayout> createState() =>
      _ResizableSplitLayoutState();
}

class _ResizableSplitLayoutState extends ConsumerState<ResizableSplitLayout> {
  @override
  Widget build(BuildContext context) {
    final currentWidth = ref.watch(widget.widthProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * widget.maxSecondWidthRatio;
        final clampedWidth = currentWidth.clamp(widget.minSecondWidth, maxWidth);

        // 计算第一面板的可用宽度
        final firstPanelWidth = constraints.maxWidth -
            clampedWidth -
            (widget.vertical ? widget.dividerWidth : 0);

        // 确保第一面板至少有最小宽度
        final effectiveFirstWidth = firstPanelWidth > widget.minSecondWidth
            ? firstPanelWidth
            : constraints.maxWidth - widget.minSecondWidth - widget.dividerWidth;

        return Row(
          children: [
            // 第一面板（自适应或固定）
            widget.vertical
                ? Expanded(child: widget.firstPanel)
                : SizedBox(width: effectiveFirstWidth, child: widget.firstPanel),

            // 可拖拽分隔线
            if (widget.vertical)
              ResizableDivider(
                width: widget.dividerWidth,
                thickness: widget.dividerThickness,
                onDrag: (delta) {
                  final newWidth = (currentWidth - delta).clamp(
                    widget.minSecondWidth,
                    constraints.maxWidth * widget.maxSecondWidthRatio,
                  );
                  ref.read(widget.widthProvider.notifier).state = newWidth;
                },
              ),

            // 第二面板（可调整宽度）
            SizedBox(
              width: widget.vertical ? clampedWidth : constraints.maxWidth,
              child: widget.secondPanel,
            ),
          ],
        );
      },
    );
  }
}
