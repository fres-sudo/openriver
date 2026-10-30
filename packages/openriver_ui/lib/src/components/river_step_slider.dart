import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../foundation/tokens.dart';

/// A slider over the whole numbers 0 to [max], such as a replay's steps.
///
/// shadcn_ui 0.2.6's `ShadSlider` wraps Material's `Slider`, which needs a
/// Material ancestor that the app does not have. This one is built from
/// primitives: a 48-pixel-tall target, tap and drag to choose a value, arrow
/// keys plus Home and End while focused, and slider semantics with
/// increase and decrease actions. It follows the text direction.
class RiverStepSlider extends StatefulWidget {
  const RiverStepSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.label,
    this.valueLabel,
    this.focusNode,
  }) : assert(max >= 0 && value >= 0 && value <= max);

  final int value;
  final int max;

  /// Called with each new value. Null disables the slider.
  final ValueChanged<int>? onChanged;

  /// Spoken name of the slider.
  final String label;

  /// Spoken value; defaults to the number.
  final String Function(int value)? valueLabel;

  final FocusNode? focusNode;

  @override
  State<RiverStepSlider> createState() => _RiverStepSliderState();
}

class _RiverStepSliderState extends State<RiverStepSlider> {
  var _focused = false;

  static const _trackHeight = 8.0;
  static const _thumbRadius = 10.0;

  bool get _enabled => widget.onChanged != null && widget.max > 0;

  void _set(int value) {
    final next = value.clamp(0, widget.max);
    if (_enabled && next != widget.value) widget.onChanged!(next);
  }

  void _setFromPosition(double dx, double width, TextDirection direction) {
    final usable = width - _thumbRadius * 2;
    if (usable <= 0) return;
    var fraction = ((dx - _thumbRadius) / usable).clamp(0.0, 1.0);
    if (direction == TextDirection.rtl) fraction = 1 - fraction;
    _set((fraction * widget.max).round());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    final int? next;
    if (key == LogicalKeyboardKey.arrowUp) {
      next = widget.value + 1;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      next = widget.value - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      next = widget.value + (rtl ? -1 : 1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      next = widget.value + (rtl ? 1 : -1);
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = widget.max;
    } else {
      next = null;
    }
    if (next == null) return KeyEventResult.ignored;
    _set(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final direction = Directionality.of(context);
    final describe = widget.valueLabel ?? (value) => '$value';
    final fraction = widget.max == 0 ? 0.0 : widget.value / widget.max;

    return Semantics(
      slider: true,
      label: widget.label,
      value: describe(widget.value),
      increasedValue: widget.value < widget.max
          ? describe(widget.value + 1)
          : null,
      decreasedValue: widget.value > 0 ? describe(widget.value - 1) : null,
      enabled: _enabled,
      onIncrease: _enabled && widget.value < widget.max
          ? () => _set(widget.value + 1)
          : null,
      onDecrease: _enabled && widget.value > 0
          ? () => _set(widget.value - 1)
          : null,
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: _enabled,
        onKeyEvent: _onKey,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              void update(Offset local) =>
                  _setFromPosition(local.dx, width, direction);
              final usable = width - _thumbRadius * 2;
              final thumbStart = usable * fraction;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _enabled ? (d) => update(d.localPosition) : null,
                onHorizontalDragStart: _enabled
                    ? (d) => update(d.localPosition)
                    : null,
                onHorizontalDragUpdate: _enabled
                    ? (d) => update(d.localPosition)
                    : null,
                child: SizedBox(
                  width: width,
                  height: RiverSizes.instance.minTapTarget,
                  child: Opacity(
                    opacity: _enabled ? 1 : 0.5,
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        PositionedDirectional(
                          start: _thumbRadius,
                          end: _thumbRadius,
                          child: Container(
                            height: _trackHeight,
                            decoration: BoxDecoration(
                              color: colors.secondary,
                              borderRadius: BorderRadius.circular(_trackHeight),
                            ),
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: fraction,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(
                                    _trackHeight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          start: thumbStart,
                          child: Container(
                            width: _thumbRadius * 2,
                            height: _thumbRadius * 2,
                            decoration: BoxDecoration(
                              color: colors.background,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.primary,
                                width: 2,
                              ),
                              boxShadow: _focused
                                  ? [
                                      BoxShadow(
                                        color: colors.ring,
                                        spreadRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
