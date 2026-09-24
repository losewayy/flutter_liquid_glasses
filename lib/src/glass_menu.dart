import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_materials.dart';
import 'glass_surface.dart';
import 'glass_theme.dart';

/// 共享浮层菜单——玻璃档浮层（menu/toast 材质：band 12 / amount −20 / blur 8
/// / sat 1.5，见 [GlassMaterials.toast]）。
///
/// - **动画**：锚点侧 fade + scale(0.98→1) + 2~3px 位移，150ms easeOut，
///   变换原点钉在锚点那一侧。
/// - **盖面色**：默认 [GlassThemeData.menuSurface]；可用 `surfaceColor`
///   参数覆盖（例如壁纸派生色）。
///
/// 用法：触发侧 `onTapDown` 拿 `details.globalPosition` 喂 [showGlassMenu]
/// （右键/左键同一入口），或直接用 [GlassMenuButton] 替代 `PopupMenuButton`。
sealed class GlassMenuEntry<T> {
  const GlassMenuEntry();
}

/// A selectable row in a glass menu.
class GlassMenuItem<T> extends GlassMenuEntry<T> {
  const GlassMenuItem({
    required this.value,
    required this.child,
    this.enabled = true,
    this.height,
  });

  final T value;
  final Widget child;
  final bool enabled;

  /// 行高；不给则按内容（文字行 30，双行项 44 之类由 child 撑）。
  final double? height;
}

/// A separator row in a glass menu.
class GlassMenuDivider<T> extends GlassMenuEntry<T> {
  const GlassMenuDivider();
}

/// 菜单相对锚点的展开方向。
enum GlassMenuPlacement {
  /// 菜单左上贴锚点，向下展开（transform-origin: top left）。
  below,

  /// 菜单左下贴锚点，向上展开（transform-origin: bottom left）。
  above,
}

/// 打开共享玻璃菜单；点遮罩外 / Esc / 选中某项关闭并返回其 value。
Future<T?> showGlassMenu<T>({
  required BuildContext context,
  required Offset anchor,
  required List<GlassMenuEntry<T>> items,
  GlassMenuPlacement placement = GlassMenuPlacement.below,
  double minWidth = 160,
  double maxWidth = 320,
  double? width,
  double maxHeight = 360,
  EdgeInsets padding = const EdgeInsets.symmetric(vertical: 4),

  /// 锚点与菜单的间距。
  double gap = 4,

  /// 玻璃盖面色；null → [GlassThemeData.menuSurface]。
  Color? surfaceColor,
}) {
  final overlay = Overlay.of(context);
  final completer = Completer<T?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _GlassMenuOverlay<T>(
      anchor: anchor,
      items: items,
      placement: placement,
      minWidth: width ?? minWidth,
      maxWidth: width ?? maxWidth,
      maxHeight: maxHeight,
      padding: padding,
      gap: gap,
      surfaceColor: surfaceColor,
      onSelect: (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      onDismiss: () {
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// `PopupMenuButton` 的等价件：child 作触发器，点击在锚点侧开 [showGlassMenu]。
class GlassMenuButton<T> extends StatefulWidget {
  const GlassMenuButton({
    super.key,
    required this.itemBuilder,
    required this.child,
    this.onSelected,
    this.tooltip,
    this.placement = GlassMenuPlacement.below,
    this.offset = Offset.zero,
    this.minWidth = 160,
    this.maxWidth = 320,
    this.width,
    this.maxHeight = 360,
    this.enabled = true,
    this.surfaceColor,
  });

  final List<GlassMenuEntry<T>> Function() itemBuilder;
  final Widget child;
  final ValueChanged<T>? onSelected;
  final String? tooltip;
  final GlassMenuPlacement placement;

  /// 相对锚点边的额外偏移。
  final Offset offset;
  final double minWidth;
  final double maxWidth;
  final double? width;
  final double maxHeight;
  final bool enabled;

  /// 玻璃盖面色；null → [GlassThemeData.menuSurface]。
  final Color? surfaceColor;

  @override
  State<GlassMenuButton<T>> createState() => _GlassMenuButtonState<T>();
}

class _GlassMenuButtonState<T> extends State<GlassMenuButton<T>> {
  final LayerLink _link = LayerLink();

  Future<void> _open() async {
    if (!widget.enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchorTopLeft = box.localToGlobal(Offset.zero);
    final anchor = widget.placement == GlassMenuPlacement.below
        ? anchorTopLeft + Offset(0, box.size.height)
        : anchorTopLeft;
    final selected = await showGlassMenu<T>(
      context: context,
      anchor: anchor + widget.offset,
      items: widget.itemBuilder(),
      placement: widget.placement,
      minWidth: widget.minWidth,
      maxWidth: widget.maxWidth,
      width: widget.width,
      maxHeight: widget.maxHeight,
      surfaceColor: widget.surfaceColor,
    );
    if (!mounted || selected == null) return;
    widget.onSelected?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    Widget trigger = CompositedTransformTarget(
      link: _link,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.enabled ? _open : null,
        child: widget.child,
      ),
    );
    if (widget.tooltip != null) {
      trigger = Tooltip(message: widget.tooltip!, child: trigger);
    }
    return trigger;
  }
}

class _GlassMenuOverlay<T> extends StatefulWidget {
  const _GlassMenuOverlay({
    required this.anchor,
    required this.items,
    required this.placement,
    required this.minWidth,
    required this.maxWidth,
    required this.maxHeight,
    required this.padding,
    required this.gap,
    required this.surfaceColor,
    required this.onSelect,
    required this.onDismiss,
    required this.onDone,
  });

  final Offset anchor;
  final List<GlassMenuEntry<T>> items;
  final GlassMenuPlacement placement;
  final double minWidth;
  final double maxWidth;
  final double maxHeight;
  final EdgeInsets padding;
  final double gap;
  final Color? surfaceColor;
  final ValueChanged<T?> onSelect;
  final VoidCallback onDismiss;
  final VoidCallback onDone;

  @override
  State<_GlassMenuOverlay<T>> createState() => _GlassMenuOverlayState<T>();
}

class _GlassMenuOverlayState<T> extends State<_GlassMenuOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    reverseDuration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.98, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  final _menuKey = GlobalKey();
  Size? _menuSize;
  bool _closing = false;
  T? _selected;

  @override
  void initState() {
    super.initState();
    // 先以 0 透明量一帧菜单尺寸，再定最终位置后淡入——两段式
    // `visibility:hidden → 定位后 visible`。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
      setState(() => _menuSize = box?.size ?? const Size(0, 0));
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close({T? select, bool dismissed = false}) async {
    if (_closing) return;
    _closing = true;
    _selected = select;
    await _controller.reverse();
    if (dismissed) {
      widget.onDismiss();
    } else {
      widget.onSelect(_selected as T);
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final size = _menuSize;
    // 水平 clamp 8px 屏边。
    double left = widget.anchor.dx;
    if (size != null) {
      left = left.clamp(8.0, (screen.width - size.width - 8).clamp(8.0, screen.width));
    }
    double top = widget.placement == GlassMenuPlacement.below
        ? widget.anchor.dy + widget.gap
        : widget.anchor.dy - widget.gap - (size?.height ?? 0);
    if (size != null) {
      top = top.clamp(8.0, (screen.height - size.height - 8).clamp(8.0, screen.height));
    }

    final material = GlassMaterials.toast(
      GlassTheme.of(context),
      surface: widget.surfaceColor,
    );
    const radius = 12.0;

    final menuSurface = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: GlassSurface(
        params: material.params.copyWith(cornerRadius: radius),
        blurSigma: material.blurSigma,
        child: _buildItems(context),
      ),
    );

    return Stack(
      children: [
        // 全屏遮罩：左/右键点击都关（右键重开新菜单由触发侧负责）。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _close(dismissed: true),
            onSecondaryTapUp: (_) => _close(dismissed: true),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              alignment: widget.placement == GlassMenuPlacement.below
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(
                      0,
                      widget.placement == GlassMenuPlacement.below
                          ? -0.01
                          : 0.01),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
                child: Opacity(
                  // 未量尺寸前不可见（等同 visibility:hidden 首帧）。
                  opacity: size == null ? 0 : 1,
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _close(dismissed: true);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: widget.minWidth,
                        maxWidth: widget.maxWidth,
                        maxHeight: widget.maxHeight,
                      ),
                      child: SingleChildScrollView(
                        key: _menuKey,
                        child: Material(
                          // overlay 不继承页面 Material：InkWell 需要祖先 Material。
                          type: MaterialType.transparency,
                          child: menuSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItems(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicWidth(
      child: Padding(
        padding: widget.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in widget.items)
              switch (entry) {
                GlassMenuDivider<T>() => Divider(
                    height: 9,
                    thickness: 0.5,
                    indent: 8,
                    endIndent: 8,
                    color: theme.dividerColor,
                  ),
                GlassMenuItem<T>() => _MenuItemTile<T>(
                    entry: entry,
                    onTap: entry.enabled
                        ? () => _close(select: entry.value)
                        : null,
                  ),
              },
          ],
        ),
      ),
    );
  }
}

/// `<select>` 的共享等价物：触发器行（当前值 + chevron）+ [showGlassMenu]
/// 浮层（锚点侧 scale+fade，不是 Material DropdownButton 的"从顶部长出来"）。
class GlassSelect<T> extends StatelessWidget {
  const GlassSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.disabledValues = const {},
    this.enabled = true,
    this.minWidth = 160,
    this.dense = false,
    this.keyName,
    this.surfaceColor,
  });

  /// 当前选中项的 value。
  final T value;

  /// `(value, label)` 有序对。
  final List<({T value, String label})> options;
  final ValueChanged<T>? onChanged;
  final Set<T> disabledValues;
  final bool enabled;
  final double minWidth;

  /// 紧凑档（高度 28，字号 12）；默认档高度 36、字号 13。
  final bool dense;

  /// 诊断锚点名（`ValueKey`）。
  final String? keyName;

  /// 菜单玻璃盖面色；null → [GlassThemeData.menuSurface]。
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usable = enabled && onChanged != null;
    final current = options
        .where((o) => o.value == value)
        .map((o) => o.label)
        .firstOrNull;
    return GlassMenuButton<T>(
      minWidth: minWidth,
      enabled: usable,
      surfaceColor: surfaceColor,
      onSelected: (v) => onChanged?.call(v),
      itemBuilder: () => [
        for (final option in options)
          GlassMenuItem<T>(
            value: option.value,
            enabled: !disabledValues.contains(option.value),
            height: 30,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (option.value == value)
                  Icon(Icons.check, size: 13, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
      ],
      child: Container(
        key: keyName == null ? null : ValueKey(keyName!),
        height: dense ? 28 : 36,
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                current ?? '$value',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      usable ? colorScheme.onSurface : Theme.of(context).disabledColor,
                  fontSize: dense ? 12 : 13,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_drop_down,
                size: dense ? 16 : 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _MenuItemTile<T> extends StatelessWidget {
  const _MenuItemTile({required this.entry, required this.onTap});

  final GlassMenuItem<T> entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Theme.of(context).hoverColor,
      borderRadius: BorderRadius.circular(6),
      child: Opacity(
        opacity: entry.enabled ? 1 : 0.5,
        child: Container(
          height: entry.height,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.centerLeft,
          child: entry.child,
        ),
      ),
    );
  }
}
