import 'package:flutter/widgets.dart';

/// 减少透明度作用域——对齐 Web `prefers-reduced-transparency: reduce` 与 Windows 高对比度/无障碍。
///
/// 当系统或用户请求减少透明度时：
/// 1. 玻璃材质硬关断（BackdropFilter 与 shader 移除，降级为实底 bgSurface）。
/// 2. 交互高光/指尖 glow 透明度归零（.glass::after opacity: 0）。
/// 3. 原生边缘描边与内阴影保留（保持层级轮廓）。
class ReducedTransparencyScope extends InheritedWidget {
  const ReducedTransparencyScope({
    super.key,
    required this.reduceTransparency,
    required super.child,
  });

  final bool reduceTransparency;

  static bool? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReducedTransparencyScope>()
        ?.reduceTransparency;
  }

  static bool of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope != null) return scope;
    final mq = MediaQuery.maybeOf(context);
    return (mq?.highContrast ?? false) || (mq?.accessibleNavigation ?? false);
  }

  @override
  bool updateShouldNotify(ReducedTransparencyScope oldWidget) =>
      reduceTransparency != oldWidget.reduceTransparency;
}
