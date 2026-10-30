import 'package:flutter/widgets.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'replay_format.dart';
import 'replay_models.dart';
import 'table_pieces.dart';

/// One occupied seat, drawn at a fixed design width and scaled to fit the
/// table slot it is given.
///
/// Everything shown comes from [view]; the seat interprets nothing.
class SeatWidget extends StatelessWidget {
  const SeatWidget({
    super.key,
    required this.view,
    required this.format,
    this.showCards = true,
    this.toAct = false,
    this.dealer = false,
  });

  final SeatView view;
  final ReplayFormat format;

  /// Whether known hole cards are drawn face up.
  final bool showCards;

  /// Highlights the seat that makes the next decision.
  final bool toAct;

  /// Whether the dealer button sits at this seat.
  final bool dealer;

  /// The width the seat is designed at before scaling.
  static const designWidth = 128.0;

  /// Design height for [designWidth] at the default text size.
  static const designHeight = 150.0;

  static const _cardWidth = 44.0;

  List<PlayingCard?> get _cards => view.holeCards ?? const [null, null];

  String semanticLabel() {
    final strings = format.strings;
    final parts = [
      strings.seatSummary(view.seat, view.name),
      if (view.position case final position?) format.positionName(position),
      if (dealer && view.position != Position.button) strings.seatDealer,
      strings.seatStack(format.amount(view.stack)),
      if (view.bet > 0) strings.seatBet(format.amount(view.bet)),
      if (view.lastAction case final action?) format.actionLabel(action),
      if (view.status == SeatStatus.folded) strings.seatFolded,
      if (view.status == SeatStatus.allIn) strings.seatAllIn,
      if (toAct) strings.seatToAct,
      if (view.won > 0) strings.seatWon(format.amount(view.won)),
      if (showCards && _cards.any((card) => card != null))
        strings.seatHolding(
          _cards
              .map(
                (card) =>
                    card == null ? strings.cardFaceDown : format.cardName(card),
              )
              .join(', '),
        ),
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = format.strings;
    final folded = view.status == SeatStatus.folded;

    // Folding dims the cards only; text keeps readable contrast.
    final ink = folded ? colors.mutedForeground : colors.cardForeground;
    final cards = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (index, card) in _cards.indexed) ...[
          if (index > 0) SizedBox(width: spacing.xs),
          Opacity(
            opacity: folded ? 0.35 : 1,
            child: PlayingCardWidget(
              card: card,
              faceUp: showCards,
              width: _cardWidth,
            ),
          ),
        ],
      ],
    );

    final box = Container(
      width: designWidth,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: folded ? colors.muted : colors.card,
        borderRadius: theme.radius,
        border: Border.all(
          color: toAct ? colors.ring : colors.border,
          width: toAct ? 3 : 1,
        ),
        boxShadow: toAct
            ? [
                BoxShadow(
                  color: colors.ring.withValues(alpha: 0.35),
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (view.position case final position?) ...[
                ShadBadge.outline(
                  padding: EdgeInsets.symmetric(horizontal: spacing.xs),
                  text: Text(format.positionBadge(position), maxLines: 1),
                ),
                SizedBox(width: spacing.xs),
              ],
              Flexible(
                child: Text(
                  view.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(color: ink),
                ),
              ),
            ],
          ),
          Text(
            format.amount(view.stack),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.small.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    final status = Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      children: [
        if (view.won > 0)
          ShadBadge(
            text: Text(strings.wonBadge(format.amount(view.won)), maxLines: 1),
          ),
        if (view.status == SeatStatus.allIn)
          ShadBadge.destructive(text: Text(strings.allIn, maxLines: 1)),
        if (view.lastAction case final action? when view.won == 0)
          ShadBadge.secondary(
            text: Text(format.actionLabel(action), maxLines: 1),
          ),
      ],
    );

    final seat = SizedBox(
      width: designWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cards,
          SizedBox(height: spacing.xs),
          box,
          SizedBox(height: spacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: status,
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: semanticLabel(),
      child: ExcludeSemantics(child: seat),
    );
  }
}

/// An unoccupied seat.
class EmptySeat extends StatelessWidget {
  const EmptySeat({super.key, required this.seat, required this.label});

  final int seat;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          width: SeatWidget.designWidth * 0.6,
          height: SeatWidget.designWidth * 0.42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colors.background.withValues(alpha: 0.4),
            borderRadius: theme.radius,
            border: Border.all(color: theme.colors.border),
          ),
          child: Text('$seat', style: theme.textTheme.muted),
        ),
      ),
    );
  }
}
