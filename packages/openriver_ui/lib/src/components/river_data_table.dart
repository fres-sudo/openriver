import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../context.dart';
import 'river_button.dart';
import 'river_icon_button.dart';

/// One visible, sortable column of a data table.
final class RiverDataColumn<T> {
  const RiverDataColumn({
    required this.id,
    required this.label,
    required this.cell,
    this.flex = 1,
  });

  final String id;
  final String label;
  final Widget Function(BuildContext context, T row) cell;
  final int flex;
}

/// A shadcn-style table surface. Data operations stay with its caller, so a
/// paged or remote source never sorts only the currently visible rows.
class RiverDataTable<T, K extends Object> extends StatefulWidget {
  const RiverDataTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.keyOf,
    required this.labelOf,
    required this.selected,
    required this.onSelectionChanged,
    required this.sortId,
    required this.descending,
    required this.onSort,
    required this.onOpen,
    required this.openLabel,
    required this.selectPageLabel,
    required this.selectRowLabel,
    required this.compactBuilder,
  });

  final List<T> rows;
  final List<RiverDataColumn<T>> columns;
  final K Function(T) keyOf;
  final String Function(T) labelOf;
  final Set<K> selected;
  final ValueChanged<Set<K>> onSelectionChanged;
  final String sortId;
  final bool descending;
  final ValueChanged<String> onSort;
  final ValueChanged<T> onOpen;
  final String openLabel;
  final String selectPageLabel;
  final String Function(T) selectRowLabel;
  final Widget Function(
    BuildContext context,
    T row,
    bool selected,
    VoidCallback onSelect,
    VoidCallback onOpen,
  )
  compactBuilder;

  @override
  State<RiverDataTable<T, K>> createState() => _RiverDataTableState<T, K>();
}

class _RiverDataTableState<T, K extends Object>
    extends State<RiverDataTable<T, K>> {
  K? _hovered;

  void _toggle(K key) {
    final next = {...widget.selected};
    if (!next.add(key)) next.remove(key);
    widget.onSelectionChanged(next);
  }

  void _togglePage() {
    final keys = widget.rows.map(widget.keyOf).toSet();
    final next = {...widget.selected};
    if (keys.every(next.contains)) {
      next.removeAll(keys);
    } else {
      next.addAll(keys);
    }
    widget.onSelectionChanged(next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 850) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in widget.rows)
              widget.compactBuilder(
                context,
                row,
                widget.selected.contains(widget.keyOf(row)),
                () => _toggle(widget.keyOf(row)),
                () => widget.onOpen(row),
              ),
          ],
        );
      }
      final theme = context.app.theme;
      final colors = theme.colors;
      final spacing = theme.spacing;
      final allSelected =
          widget.rows.isNotEmpty &&
          widget.rows.every(
            (row) => widget.selected.contains(widget.keyOf(row)),
          );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.border),
          borderRadius: theme.radius,
        ),
        child: ClipRRect(
          borderRadius: theme.radius,
          child: Column(
            children: [
              Container(
                color: colors.muted.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    _checkbox(
                      value: allSelected,
                      label: widget.selectPageLabel,
                      onChanged: _togglePage,
                    ),
                    for (final column in widget.columns)
                      Expanded(
                        flex: column.flex,
                        child: RiverButton(
                          label: column.label,
                          icon: widget.sortId == column.id
                              ? (widget.descending
                                    ? LucideIcons.arrowDown
                                    : LucideIcons.arrowUp)
                              : LucideIcons.arrowUpDown,
                          variant: RiverButtonVariant.ghost,
                          onPressed: () => widget.onSort(column.id),
                        ),
                      ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              for (final row in widget.rows) ...[
                Container(height: 1, color: colors.border),
                MouseRegion(
                  onEnter: (_) => setState(() => _hovered = widget.keyOf(row)),
                  onExit: (_) => setState(() => _hovered = null),
                  child: ColoredBox(
                    color: widget.selected.contains(widget.keyOf(row))
                        ? colors.secondary
                        : _hovered == widget.keyOf(row)
                        ? colors.muted.withValues(alpha: 0.45)
                        : colors.card,
                    child: Row(
                      children: [
                        _checkbox(
                          value: widget.selected.contains(widget.keyOf(row)),
                          label: widget.selectRowLabel(row),
                          onChanged: () => _toggle(widget.keyOf(row)),
                        ),
                        for (final column in widget.columns)
                          Expanded(
                            flex: column.flex,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing.sm,
                                vertical: spacing.sm,
                              ),
                              child: DefaultTextStyle(
                                style: theme.textTheme.small.copyWith(
                                  color: colors.foreground,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                child: column.cell(context, row),
                              ),
                            ),
                          ),
                        RiverIconButton(
                          icon: LucideIcons.chevronRight,
                          label: '${widget.openLabel}: ${widget.labelOf(row)}',
                          mirrorInRtl: true,
                          onPressed: () => widget.onOpen(row),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _checkbox({
    required bool value,
    required String label,
    required VoidCallback onChanged,
  }) => Semantics(
    label: label,
    checked: value,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: ShadCheckbox(value: value, onChanged: (_) => onChanged()),
        ),
      ),
    ),
  );
}
