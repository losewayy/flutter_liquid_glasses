import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_liquid_glasses/flutter_liquid_glasses.dart';

void main() => runApp(const DemoApp());

enum BackdropKind { bars, gradient, aurora, text }

enum _Lang { en, zh }

/// Minimal two-locale strings — the playground is the audience-facing demo.
class _S {
  const _S(this.lang);

  final _Lang lang;

  bool get zh => lang == _Lang.zh;

  String get subtitle => zh ? 'Kyant 光学游乐场' : 'Kyant optics playground';
  String get preset => zh ? '预设' : 'Preset';
  String get backdrop => zh ? '背板' : 'Backdrop';
  String get lens => zh ? '镜片' : 'Lens';
  String get colorControls => zh ? '色彩控制' : 'Color controls';
  String get highlight => zh ? '高光' : 'Highlight';
  String get innerShadow => zh ? '内阴影' : 'Inner shadow';
  String get surface => zh ? '表面' : 'Surface';
  String get staticOptics => zh ? '静态光学' : 'static optics';
  String get jellyHint => zh ? '按住拖我 —— 果冻玻璃' : 'Press & drag me — jelly glass';
  String get segmentedHint => zh ? '点击或按住左右拖动' : 'Tap or press & drag sideways';
  String get dialogButton => zh ? '玻璃对话框' : 'Glass dialog';
  String get dialogBody =>
      zh ? 'GlassDialog —— 浮层档位' : 'GlassDialog — overlay tier';
  String get showToast => zh ? '弹出 Toast' : 'Show toast';
  String get toastHint => zh ? '左右滑动消除我' : 'Swipe me sideways to dismiss';
  String get menu => zh ? '菜单' : 'Menu';
  String get reset => zh ? '恢复默认' : 'Reset';

  /// Renderer-path badge: ImageFilter.shader (backdrop refraction) exists
  /// only on Impeller; web/Skia builds run the honest blur+tint fallback.
  String get rendererBadge => ui.ImageFilter.isShaderFilterSupported
      ? (zh ? '光学 · Impeller' : 'Optics · Impeller')
      : (zh ? '降级渲染 · 无折射' : 'Fallback · no refraction');
  List<String> get segLabels =>
      zh ? const ['左', '中', '右'] : const ['L', 'C', 'R'];

  /// Slider rows: zh display name, param name stays English (it's the API).
  String sliderName(String en) => switch ((en, zh)) {
    ('cornerRadius', true) => '圆角半径',
    ('refractionHeight', true) => '折射带高度',
    ('refractionAmount', true) => '折射强度',
    ('depthEffect', true) => '深度感',
    ('chromatic', true) => '色散强度',
    ('saturation', true) => '饱和度',
    ('brightness', true) => '亮度',
    ('contrast', true) => '对比度',
    ('tint hue', true) => '染色色相',
    ('tint alpha', true) => '染色浓度',
    ('surface alpha', true) => '盖面浓度',
    ('stroke', true) => '描边宽度',
    ('alpha', true) => '不透明度',
    ('angle', true) => '光源角度',
    ('falloff', true) => '衰减',
    ('blur', true) => '模糊半径',
    ('offset Y', true) => 'Y 偏移',
    ('backdrop blur σ', true) => '背景模糊 σ',
    _ => en,
  };

  String presetName(String en) => switch ((en, zh)) {
    ('Composer', true) => '输入胶囊',
    ('Navigation', true) => '导航',
    ('Palette', true) => '指令面板',
    ('Card', true) => '卡片',
    ('Toast', true) => '轻提示',
    ('Overlay', true) => '浮层',
    ('Custom', true) => '自定义',
    _ => en,
  };

  String backdropName(BackdropKind k) => switch ((k, zh)) {
    (BackdropKind.bars, true) => '色块',
    (BackdropKind.gradient, true) => '渐变',
    (BackdropKind.aurora, true) => '极光',
    (BackdropKind.text, true) => '文本',
    (BackdropKind.bars, false) => 'Bars',
    (BackdropKind.gradient, false) => 'Grad',
    (BackdropKind.aurora, false) => 'Aurora',
    (BackdropKind.text, false) => 'Text',
  };
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        sliderTheme: const SliderThemeData(
          trackHeight: 2,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        ),
      ),
      home: const GlassTheme(data: GlassThemeData(), child: Playground()),
    );
  }
}

class Playground extends StatefulWidget {
  const Playground({super.key});

  @override
  State<Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends State<Playground> {
  // Authoritative launch-state snapshot — the reset button restores this.
  static const _defaultParams = GlassParams(
    cornerRadius: 25,
    refractionHeight: 18,
    refractionAmount: -34,
    depthEffect: 1,
    chromatic: 2.0,
    saturation: 1.5,
    tintColor: [0.4, 0.5, 0.8, 0.12],
    highlightStroke: 1,
    highlightAlpha: .38,
    highlightAngle: .785398,
    shadowAlpha: .25,
  );
  static const _defaultBlurSigma = 2.0;
  static const _defaultTintHue = 220.0;
  static const _defaultPreset = 'Composer';
  static const _defaultBackdrop = BackdropKind.bars;

  // Live-edited optics; preset chips overwrite the whole set at once.
  GlassParams _params = _defaultParams;
  double _blurSigma = _defaultBlurSigma;
  double _tintHue = _defaultTintHue;
  String _preset = _defaultPreset;
  BackdropKind _backdrop = _defaultBackdrop;
  _Lang _lang = _Lang.en;
  bool _toastVisible = true;
  String _selectValue = 'Medium';
  int _segment = 1;

  static const _presets = <String, GlassMaterialToken Function(GlassThemeData)>{
    'Composer': GlassMaterials.composer,
    'Navigation': GlassMaterials.navigation,
    'Palette': GlassMaterials.commandPalette,
    'Card': GlassMaterials.card,
    'Toast': GlassMaterials.toast,
    'Overlay': GlassMaterials.overlay,
  };

  void _set(GlassParams Function(GlassParams) update) {
    setState(() {
      _params = update(_params);
      _preset = 'Custom';
    });
  }

  void _applyPreset(String name, GlassThemeData theme) {
    final token = _presets[name]!(theme);
    setState(() {
      _preset = name;
      _params = token.params;
      _blurSigma = token.blurSigma;
      _tintHue = _hueOf(token.params.tintColor);
    });
  }

  void _reset() => setState(() {
    _params = _defaultParams;
    _blurSigma = _defaultBlurSigma;
    _tintHue = _defaultTintHue;
    _preset = _defaultPreset;
    _backdrop = _defaultBackdrop;
    _toastVisible = true;
    _selectValue = 'Medium';
    _segment = 1;
  });

  static double _hueOf(List<double> rgba) {
    if (rgba[3] <= 0) return 220;
    final c = Color.fromARGB(
      255,
      (rgba[0] * 255).round(),
      (rgba[1] * 255).round(),
      (rgba[2] * 255).round(),
    );
    return HSVColor.fromColor(c).hue;
  }

  void _withTint(double hue, double alpha) {
    final c = HSVColor.fromAHSV(1, hue, .55, .9).toColor();
    _set((p) => p.copyWith(tintColor: [c.r, c.g, c.b, alpha]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = GlassTheme.of(context);
    final s = _S(_lang);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Row(
        children: [
          SizedBox(
            width: 288,
            child: _ControlPanel(
              params: _params,
              blurSigma: _blurSigma,
              tintHue: _tintHue,
              preset: _preset,
              presetNames: _presets.keys.toList(),
              backdrop: _backdrop,
              lang: _lang,
              s: s,
              onLang: (l) => setState(() => _lang = l),
              onReset: _reset,
              onPreset: (name) => _applyPreset(name, theme),
              onBackdrop: (b) => setState(() => _backdrop = b),
              onBlur: (v) => setState(() => _blurSigma = v),
              onParam: _set,
              onTint: _withTint,
            ),
          ),
          Expanded(child: ClipRect(child: _stage(theme, s))),
        ],
      ),
    );
  }

  Widget _stage(GlassThemeData theme, _S s) {
    final seg = s.segLabels;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: _Backdrop(kind: _backdrop)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _caption(s.segmentedHint),
                SizedBox(
                  width: 300,
                  child: GlassSegmentedControl<int>(
                    segments: [
                      GlassSegment(value: 0, label: seg[0]),
                      GlassSegment(value: 1, label: seg[1]),
                      GlassSegment(value: 2, label: seg[2]),
                    ],
                    selected: _segment,
                    onChanged: (v) => setState(() => _segment = v),
                    height: 38,
                  ),
                ),
                const SizedBox(height: 28),
                _caption('GlassSurface — ${s.staticOptics}'),
                GlassSurface(
                  params: _params,
                  blurSigma: _blurSigma,
                  child: const SizedBox(
                    width: 340,
                    height: 104,
                    child: SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 24),
                _caption(s.jellyHint),
                GlassPressSurface(
                  params: _params,
                  blurSigma: _blurSigma,
                  child: const SizedBox(width: 220, height: 56),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _ghostButton(s.dialogButton, () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => GlassDialog(
                          width: 340,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              s.dialogBody,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    }),
                    _ghostButton(
                      s.showToast,
                      () => setState(() => _toastVisible = true),
                    ),
                    GlassMenuButton<String>(
                      tooltip: 'Glass menu',
                      onSelected: (v) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(s.zh ? '菜单选中：$v' : 'Menu picked: $v'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      itemBuilder: () => const [
                        GlassMenuItem(
                          value: 'a',
                          height: 30,
                          child: Text('Alpha'),
                        ),
                        GlassMenuItem(
                          value: 'b',
                          height: 30,
                          child: Text('Beta'),
                        ),
                        GlassMenuDivider(),
                        GlassMenuItem(
                          value: 'c',
                          height: 30,
                          child: Text('Gamma'),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          s.menu,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    GlassSelect<String>(
                      value: _selectValue,
                      options: const [
                        (value: 'Small', label: 'Small'),
                        (value: 'Medium', label: 'Medium'),
                        (value: 'Large', label: 'Large'),
                      ],
                      onChanged: (v) => setState(() => _selectValue = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_toastVisible)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: LiquidSwipeSurface(
                onDismissed: () => setState(() => _toastVisible = false),
                child: GlassSurface(
                  params: GlassMaterials.toast(theme).params,
                  blurSigma: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Text(
                      s.toastHint,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: Colors.white38),
    ),
  );

  Widget _ghostButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: .18)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

/// Parameter playground panel — every shader uniform is a live slider.
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.params,
    required this.blurSigma,
    required this.tintHue,
    required this.preset,
    required this.presetNames,
    required this.backdrop,
    required this.lang,
    required this.s,
    required this.onLang,
    required this.onReset,
    required this.onPreset,
    required this.onBackdrop,
    required this.onBlur,
    required this.onParam,
    required this.onTint,
  });

  final GlassParams params;
  final double blurSigma;
  final double tintHue;
  final String preset;
  final List<String> presetNames;
  final BackdropKind backdrop;
  final _Lang lang;
  final _S s;
  final ValueChanged<_Lang> onLang;
  final VoidCallback onReset;
  final ValueChanged<String> onPreset;
  final ValueChanged<BackdropKind> onBackdrop;
  final ValueChanged<double> onBlur;
  final void Function(GlassParams Function(GlassParams)) onParam;
  final void Function(double hue, double alpha) onTint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E14),
        border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'flutter_liquid_glasses',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .2,
                      ),
                    ),
                    Text(
                      s.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ui.ImageFilter.isShaderFilterSupported
                            ? const Color(0x1A4ADE80)
                            : const Color(0x1AF59E0B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s.rendererBadge,
                        style: TextStyle(
                          fontSize: 9,
                          color: ui.ImageFilter.isShaderFilterSupported
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onReset,
                tooltip: s.reset,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withValues(alpha: .12)),
                ),
                icon: const Icon(Icons.restart_alt),
              ),
              const SizedBox(width: 6),
              _LangToggle(lang: lang, onChanged: onLang),
            ],
          ),
          _section(s.preset),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in presetNames)
                _PresetChip(
                  label: s.presetName(name),
                  selected: preset == name,
                  onTap: () => onPreset(name),
                ),
            ],
          ),
          _section(s.backdrop),
          SegmentedButton<BackdropKind>(
            segments: [
              for (final k in BackdropKind.values)
                ButtonSegment(value: k, label: Text(s.backdropName(k))),
            ],
            selected: {backdrop},
            onSelectionChanged: (sel) => onBackdrop(sel.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
            ),
          ),
          _section(s.lens),
          _slider(
            'cornerRadius',
            params.cornerRadius,
            0,
            48,
            (v) => onParam((p) => p.copyWith(cornerRadius: v)),
          ),
          _slider(
            'refractionHeight',
            params.refractionHeight,
            0,
            48,
            (v) => onParam((p) => p.copyWith(refractionHeight: v)),
          ),
          _slider(
            'refractionAmount',
            params.refractionAmount,
            -80,
            40,
            (v) => onParam((p) => p.copyWith(refractionAmount: v)),
          ),
          _slider(
            'depthEffect',
            params.depthEffect,
            0,
            2,
            (v) => onParam((p) => p.copyWith(depthEffect: v)),
            hint: s.zh ? '细微·弯法线' : 'subtle',
          ),
          _slider(
            'chromatic',
            params.chromatic,
            0,
            6,
            (v) => onParam((p) => p.copyWith(chromatic: v)),
            hint: s.zh ? '看边缘色边' : 'edge fringes',
          ),
          _section(s.colorControls),
          _slider(
            'saturation',
            params.saturation,
            0,
            2,
            (v) => onParam((p) => p.copyWith(saturation: v)),
          ),
          _slider(
            'brightness',
            params.brightness,
            -0.4,
            0.4,
            (v) => onParam((p) => p.copyWith(brightness: v)),
          ),
          _slider(
            'contrast',
            params.contrast,
            0,
            2,
            (v) => onParam((p) => p.copyWith(contrast: v)),
          ),
          _slider(
            'tint hue',
            tintHue,
            0,
            360,
            (v) => onTint(v, params.tintColor[3]),
            hint: s.zh ? '需tint α>0' : 'needs tint α>0',
          ),
          _slider(
            'tint alpha',
            params.tintColor[3],
            0,
            0.6,
            (v) => onTint(tintHue, v),
          ),
          _slider(
            'surface alpha',
            params.surfaceColor[3],
            0,
            0.85,
            (v) =>
                onParam((p) => p.copyWith(surfaceColor: [0.04, 0.04, 0.07, v])),
            hint: s.zh ? '过高会盖住折射' : 'masks the lens when high',
          ),
          _section(s.highlight),
          _slider(
            'stroke',
            params.highlightStroke,
            0,
            8,
            (v) => onParam((p) => p.copyWith(highlightStroke: v)),
          ),
          _slider(
            'alpha',
            params.highlightAlpha,
            0,
            1,
            (v) => onParam((p) => p.copyWith(highlightAlpha: v)),
          ),
          _slider(
            'angle',
            params.highlightAngle,
            -1.6,
            1.6,
            (v) => onParam((p) => p.copyWith(highlightAngle: v)),
            hint: s.zh ? '细微·光向' : 'subtle',
          ),
          _slider(
            'falloff',
            params.highlightFalloff,
            0.1,
            3,
            (v) => onParam((p) => p.copyWith(highlightFalloff: v)),
            hint: s.zh ? '细微' : 'subtle',
          ),
          _slider(
            'blur',
            params.highlightBlur,
            0,
            8,
            (v) => onParam((p) => p.copyWith(highlightBlur: v)),
            hint: s.zh ? '细微' : 'subtle',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SegmentedButton<double>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(s.zh ? '方向性' : 'Directional'),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(s.zh ? '均匀描边' : 'Plain rim'),
                ),
              ],
              selected: {params.highlightMode >= 1.5 ? 2.0 : 0.0},
              onSelectionChanged: (sel) =>
                  onParam((p) => p.copyWith(highlightMode: sel.first)),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
              ),
            ),
          ),
          _section(s.innerShadow),
          _slider(
            'alpha',
            params.shadowAlpha,
            0,
            0.8,
            (v) => onParam((p) => p.copyWith(shadowAlpha: v)),
          ),
          _slider(
            'offset Y',
            params.shadowOffsetY,
            -8,
            8,
            (v) => onParam((p) => p.copyWith(shadowOffsetY: v)),
            hint: s.zh ? '细微' : 'subtle',
          ),
          _slider(
            'blur',
            params.shadowBlur,
            0,
            16,
            (v) => onParam((p) => p.copyWith(shadowBlur: v)),
            hint: s.zh ? '细微' : 'subtle',
          ),
          _section(s.surface),
          _slider('backdrop blur σ', blurSigma, 0, 24, onBlur),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            color: Colors.white38,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1, color: Color(0x14FFFFFF))),
      ],
    ),
  );

  Widget _slider(
    String name,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String? hint,
  }) {
    final label = s.sliderName(name);
    return SizedBox(
      height: label == name ? 26 : 30,
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: label == name
                ? Text(
                    name,
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        hint == null ? name : '$name ·$hint',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ghost-style preset chip — explicit colors so unselected labels stay
/// readable on the dark panel (M3 ChoiceChip label color resolves dark
/// on dark here).
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected
          ? accent.withValues(alpha: .85)
          : Colors.white.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0x00000000)
                  : Colors.white.withValues(alpha: .14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? const Color(0xFF14121E) : Colors.white70,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.lang, required this.onChanged});

  final _Lang lang;
  final ValueChanged<_Lang> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      color: Colors.white.withValues(alpha: .85),
    );
    return Container(
      decoration: ShapeDecoration(
        color: const Color(0x0FFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: .12)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (l, label) in [(_Lang.en, 'EN'), (_Lang.zh, '中')])
            GestureDetector(
              onTap: () => onChanged(l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: ShapeDecoration(
                  color: lang == l
                      ? Colors.white.withValues(alpha: .16)
                      : const Color(0x00000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(label, style: style),
              ),
            ),
        ],
      ),
    );
  }
}

/// Busy backdrops so refraction and dispersion have something to chew on.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.kind});

  final BackdropKind kind;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      BackdropKind.text => const _TextBackdrop(),
      _ => CustomPaint(
        painter: _BackdropPainter(kind),
        child: const SizedBox.expand(),
      ),
    };
  }
}

class _TextBackdrop extends StatelessWidget {
  const _TextBackdrop();

  @override
  Widget build(BuildContext context) {
    const line = 'The quick brown fox jumps over the lazy dog 0123456789 ';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20304F), Color(0xFF40202F), Color(0xFF1F4038)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          List.filled(200, line).join(),
          style: const TextStyle(
            fontSize: 15,
            height: 1.7,
            color: Color(0x99FFFFFF),
          ),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.kind);

  final BackdropKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (kind) {
      case BackdropKind.bars:
        _baseGradient(canvas, rect);
        _bars(canvas, size);
      case BackdropKind.gradient:
        _baseGradient(canvas, rect);
      case BackdropKind.aurora:
        _aurora(canvas, size);
      case BackdropKind.text:
        break;
    }
  }

  void _baseGradient(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20304F), Color(0xFF40202F), Color(0xFF1F4038)],
        ).createShader(rect),
    );
  }

  void _bars(Canvas canvas, Size size) {
    final paint = Paint();
    const colors = [
      Color(0xFFED2040),
      Color(0xFF20E040),
      Color(0xFF2060FF),
      Color(0xFFFFD020),
      Color(0xFF8020ED),
      Color(0xFF20C0C0),
    ];
    const bar = 36.0;
    var i = 0;
    for (var y = -bar; y < size.height + bar; y += bar * 1.6) {
      for (var x = -bar; x < size.width + bar; x += bar * 2.2) {
        paint.color = colors[(i++) % colors.length].withValues(alpha: .55);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + (y / bar).floor() * 18, y, bar * 1.4, bar * .7),
            const Radius.circular(8),
          ),
          paint,
        );
      }
    }
  }

  void _aurora(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0A14),
    );
    final blobs = [
      (Offset(size.width * .25, size.height * .3), const Color(0xFF2060FF)),
      (Offset(size.width * .7, size.height * .25), const Color(0xFF8020ED)),
      (Offset(size.width * .5, size.height * .65), const Color(0xFF20C0C0)),
      (Offset(size.width * .85, size.height * .75), const Color(0xFFED2040)),
      (Offset(size.width * .15, size.height * .8), const Color(0xFFFFD020)),
    ];
    for (final (center, color) in blobs) {
      canvas.drawCircle(
        center,
        math.min(size.width, size.height) * .28,
        Paint()
          ..color = color.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
