import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'replay_format.dart';
import 'replay_models.dart';
import 'seat_widget.dart';
import 'table_pieces.dart';

/// The table at one replay step: felt, seats on an ellipse, bets, the
/// dealer button, the board, and the pot.
///
/// Seats are numbered clockwise and rotated so [focusSeat] sits at the
/// bottom center. The table picks its own height from its width: a tall
/// oval on narrow screens and a wide one otherwise.
class ReplayTable extends StatelessWidget {
  const ReplayTable({
    super.key,
    required this.replay,
    required this.step,
    required this.format,
    this.focusSeat,
    this.revealAll = true,
  });

  final Replay replay;
  final ReplayStep step;
  final ReplayFormat format;

  /// Seat drawn at the bottom center; defaults to [defaultFocusSeat].
  final int? focusSeat;

  /// Whether every seat's known cards are face up. When false, only
  /// [focusSeat]'s are.
  final bool revealAll;

  /// The first seat with any known hole card, else the lowest seat.
  static int? defaultFocusSeat(Replay replay) {
    if (replay.steps.isEmpty) return null;
    final seats = replay.steps.first.seats;
    for (final view in seats) {
      if (view.holeCards?.any((card) => card != null) ?? false) {
        return view.seat;
      }
    }
    return seats.isEmpty ? null : seats.first.seat;
  }

  /// Wide tables below this width become tall ovals.
  static const _tallBelow = 560.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tall = constraints.maxWidth < _tallBelow;
        var width = constraints.maxWidth;
        var height = width * (tall ? 1.3 : 0.6);
        if (constraints.hasBoundedHeight && height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = math.min(width, height / (tall ? 1.3 : 0.6));
        }
        // The table is a drawing scaled to its slot, so larger text would
        // only shrink everything else. Narrow tables keep the default size;
        // wide ones allow some growth. Seat semantics, the announcement,
        // the log, and the controls follow the full text scale.
        final table = MediaQuery.withClampedTextScaling(
          maxScaleFactor: tall ? 1 : 1.5,
          child: SizedBox(
            width: constraints.maxWidth,
            height: height,
            child: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Directionality(
                  // Seat positions are geometry, not reading order.
                  textDirection: TextDirection.ltr,
                  child: _layout(Size(width, height), tall),
                ),
              ),
            ),
          ),
        );
        if (!tall) return table;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PotRow(step: step, format: format),
            SizedBox(height: context.app.theme.spacing.sm),
            table,
          ],
        );
      },
    );
  }

  Widget _layout(Size size, bool tall) {
    final capacity = math.max(
      replay.tableCapacity,
      step.seats.fold(0, (max, view) => math.max(max, view.seat)),
    );
    final crowded = capacity > 6;
    final seatWidth = math.min(
      size.width * (tall ? (crowded ? 0.22 : 0.27) : (crowded ? 0.13 : 0.16)),
      150.0,
    );
    final seatHeight =
        seatWidth * SeatWidget.designHeight / SeatWidget.designWidth;
    final center = size.center(Offset.zero);
    final radii = Offset(
      size.width / 2 - seatWidth / 2,
      size.height / 2 - seatHeight / 2,
    );
    final focus = focusSeat ?? defaultFocusSeat(replay) ?? 1;

    Offset seatCenter(int seat) {
      final slot = (seat - focus) % capacity;
      // Screen angles grow clockwise; π/2 is the bottom center.
      final angle = math.pi / 2 + 2 * math.pi * slot / capacity;
      return center +
          Offset(math.cos(angle) * radii.dx, math.sin(angle) * radii.dy);
    }

    final seatSize = Size(seatWidth, seatHeight);
    final betSize = Size(seatWidth * 0.9, seatWidth * 0.24);
    final buttonSize = Size.square((seatWidth * 0.2).clamp(18.0, 28.0));

    // Places a box of [size] just outside the seat at [at], along [toward].
    Offset beside(Offset at, Offset toward, Size size) {
      final unit = toward / toward.distance;
      double reach(Size box) => math.min(
        unit.dx == 0 ? double.infinity : box.width / 2 / unit.dx.abs(),
        unit.dy == 0 ? double.infinity : box.height / 2 / unit.dy.abs(),
      );
      return at + unit * (reach(seatSize) + reach(size) + 4);
    }

    final views = {for (final view in step.seats) view.seat: view};
    final cardWidth = (size.width * (tall ? 0.075 : 0.05)).clamp(22.0, 56.0);
    final middleWidth = size.width * (tall ? 0.44 : 0.56);
    final children = <Widget>[
      Positioned(
        left: seatWidth * 0.5,
        right: seatWidth * 0.5,
        top: seatHeight * 0.5,
        bottom: seatHeight * 0.5,
        child: const TableFelt(),
      ),
      Positioned(
        left: center.dx - middleWidth / 2,
        width: middleWidth,
        top: center.dy - cardWidth * 1.1,
        height: cardWidth * 2.2,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: _Middle(
            step: step,
            format: format,
            cardWidth: cardWidth,
            showPot: !tall,
          ),
        ),
      ),
    ];

    for (var seat = 1; seat <= capacity; seat++) {
      final view = views[seat];
      final at = seatCenter(seat);
      if (view == null) {
        children.add(
          _centeredAt(
            at,
            Size(seatWidth * 0.6, seatWidth * 0.42),
            FittedBox(
              child: EmptySeat(
                seat: seat,
                label: format.strings.seatEmpty(seat),
              ),
            ),
          ),
        );
        continue;
      }
      final inward = center - at;
      if (view.bet > 0) {
        children.add(
          _centeredAt(
            beside(at, inward, betSize),
            betSize,
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ExcludeSemantics(
                child: ChipStack(amount: format.amount(view.bet)),
              ),
            ),
          ),
        );
      }
      if (replay.buttonSeat == seat) {
        // Turned off the bet's line so the two never stack.
        final turned = Offset(
          inward.dx * math.cos(0.7) - inward.dy * math.sin(0.7),
          inward.dx * math.sin(0.7) + inward.dy * math.cos(0.7),
        );
        children.add(
          _centeredAt(
            beside(at, turned, buttonSize),
            buttonSize,
            _DealerButton(label: format.strings.dealerButton),
          ),
        );
      }
      children.add(
        _centeredAt(
          at,
          Size(seatWidth, seatHeight),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SeatWidget(
              key: ValueKey('seat-$seat'),
              view: view,
              format: format,
              showCards: revealAll || seat == focus,
              toAct: step.nextToAct == seat,
              dealer: replay.buttonSeat == seat,
            ),
          ),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  static Widget _centeredAt(Offset at, Size size, Widget child) => Positioned(
    left: at.dx - size.width / 2,
    top: at.dy - size.height / 2,
    width: size.width,
    height: size.height,
    child: Center(child: child),
  );
}

/// The board, flanked by the pot and side pots on wide tables.
class _Middle extends StatelessWidget {
  const _Middle({
    required this.step,
    required this.format,
    required this.cardWidth,
    required this.showPot,
  });

  final ReplayStep step;
  final ReplayFormat format;
  final double cardWidth;

  /// Whether the pot is drawn here rather than above the table.
  final bool showPot;

  @override
  Widget build(BuildContext context) {
    final spacing = context.app.theme.spacing;
    final pot = _Pot(step: step, format: format);
    final board = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(width: cardWidth * 0.12),
          if (i < step.board.length)
            PlayingCardWidget(
              card: step.board[i],
              width: cardWidth,
              label: format.cardName(step.board[i]),
            )
          else
            _EmptyCardSlot(width: cardWidth),
        ],
      ],
    );
    if (!showPot) return board;
    // The pot flanks the board, so seats above and below keep clear space
    // for their bets. Equal flanks keep the board centered.
    final flank = cardWidth * 3.2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: flank,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            spacing: spacing.xs,
            children: [
              for (final child in pot.collected(context))
                FittedBox(fit: BoxFit.scaleDown, child: child),
            ],
          ),
        ),
        SizedBox(width: spacing.md),
        board,
        SizedBox(width: spacing.md),
        SizedBox(
          width: flank,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: spacing.xs,
            children: [
              for (final child in pot.declared())
                FittedBox(fit: BoxFit.scaleDown, child: child),
            ],
          ),
        ),
      ],
    );
  }
}

/// The collected pot, the total with bets in front, and declared pots.
final class _Pot {
  const _Pot({required this.step, required this.format});

  final ReplayStep step;
  final ReplayFormat format;

  List<Widget> collected(BuildContext context) {
    final theme = context.app.theme;
    final total = step.totalPot;
    return [
      if (step.pot > 0)
        ChipStack(
          emphasized: true,
          amount: format.strings.potTotal(format.amount(step.pot)),
        ),
      if (total != step.pot)
        Text(
          format.strings.potWithBets(format.amount(total)),
          style: theme.textTheme.small.copyWith(color: theme.colors.foreground),
        ),
    ];
  }

  List<Widget> declared() => [
    for (final (index, pot) in step.pots.indexed)
      ShadBadge.outline(
        text: Text(
          '${format.potShortName(index)} ${format.amount(pot.amount)}',
          maxLines: 1,
        ),
      ),
  ];
}

/// The pot above a tall table, where the felt has no room beside the board.
class _PotRow extends StatelessWidget {
  const _PotRow({required this.step, required this.format});

  final ReplayStep step;
  final ReplayFormat format;

  @override
  Widget build(BuildContext context) {
    final spacing = context.app.theme.spacing;
    final pot = _Pot(step: step, format: format);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: spacing.sm,
        runSpacing: spacing.xs,
        children: [...pot.collected(context), ...pot.declared()],
      ),
    );
  }
}

class _EmptyCardSlot extends StatelessWidget {
  const _EmptyCardSlot({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = TablePalette.of(context);
    return Container(
      width: width,
      height: width * PlayingCardWidget.aspectRatio,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: palette.feltEdge.withValues(alpha: 0.35)),
      ),
    );
  }
}

class _DealerButton extends StatelessWidget {
  const _DealerButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('dealer-button'),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colors.foreground,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colors.background, width: 2),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              label,
              style: theme.textTheme.small.copyWith(
                color: theme.colors.background,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
