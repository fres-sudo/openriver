import 'package:flutter/widgets.dart';
import 'package:openriver_ui/openriver_ui.dart';

import 'replay_format.dart';
import 'replay_models.dart';

/// Table colors, all derived from the current theme.
final class TablePalette {
  const TablePalette._(this.colors);

  factory TablePalette.of(BuildContext context) =>
      TablePalette._(context.app.theme.colors);

  final ShadColorScheme colors;

  /// The felt: the primary green washed into the background, light or dark.
  Color get felt => Color.alphaBlend(
    colors.primary.withValues(alpha: 0.16),
    colors.background,
  );

  Color get feltEdge => colors.primary.withValues(alpha: 0.55);

  Color get cardFace => colors.card;
  Color get cardBorder => colors.border;

  /// Clubs and spades.
  Color get blackSuit => colors.cardForeground;

  /// Hearts and diamonds. The themes keep destructive at AA contrast on
  /// the card surface in both brightnesses.
  Color get redSuit => colors.destructive;

  Color get cardBack => colors.primary;
  Color get cardBackPattern => colors.primaryForeground.withValues(alpha: 0.45);

  Color get chip => colors.primary;
  Color get chipEdge => colors.primaryForeground;
}

/// A playing card, face up or face down, sized by [width].
///
/// Red suits use the theme's destructive color and black suits its card
/// foreground; the suit glyph itself also tells them apart. The glyphs are
/// sized to the card, so they ignore the text scale; the spoken label
/// carries the card for screen readers.
class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    required this.card,
    required this.width,
    this.faceUp = true,
    this.label,
  });

  /// Null draws a face-down card.
  final PlayingCard? card;
  final double width;
  final bool faceUp;

  /// Spoken name; null excludes the card from semantics.
  final String? label;

  static const aspectRatio = 1.4;

  @override
  Widget build(BuildContext context) {
    final palette = TablePalette.of(context);
    final textTheme = context.app.theme.textTheme;
    final height = width * aspectRatio;
    final radius = BorderRadius.circular(width * 0.12);
    final card = this.card;
    final Widget face;
    if (card == null || !faceUp) {
      face = DecoratedBox(
        key: const ValueKey('card-back'),
        decoration: BoxDecoration(
          color: palette.cardBack,
          borderRadius: radius,
        ),
        child: Padding(
          padding: EdgeInsets.all(width * 0.1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: palette.cardBackPattern,
                width: width * 0.04,
              ),
              borderRadius: BorderRadius.circular(width * 0.08),
            ),
          ),
        ),
      );
    } else {
      final red = card.suit == Suit.hearts || card.suit == Suit.diamonds;
      final style = textTheme.small.copyWith(
        color: red ? palette.redSuit : palette.blackSuit,
        fontWeight: FontWeight.w700,
        height: 1,
      );
      face = DecoratedBox(
        decoration: BoxDecoration(
          color: palette.cardFace,
          borderRadius: radius,
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ReplayFormat.rankSymbol(card.rank),
              textScaler: TextScaler.noScaling,
              style: style.copyWith(
                fontSize: width * (card.rank == Rank.ten ? 0.4 : 0.48),
                letterSpacing: card.rank == Rank.ten ? -width * 0.04 : null,
              ),
            ),
            SizedBox(height: width * 0.06),
            Text(
              ReplayFormat.suitSymbol(card.suit),
              textScaler: TextScaler.noScaling,
              style: style.copyWith(fontSize: width * 0.44),
            ),
          ],
        ),
      );
    }
    final sized = SizedBox(width: width, height: height, child: face);
    final label = this.label;
    if (label == null) return ExcludeSemantics(child: sized);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: sized),
    );
  }
}

/// Chips with an amount, such as a bet in front of a seat or a pot.
class ChipStack extends StatelessWidget {
  const ChipStack({super.key, required this.amount, this.emphasized = false});

  final String amount;

  /// Draws a filled pill, for the pot.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    final palette = TablePalette.of(context);
    final colors = theme.colors;
    const disc = 12.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? colors.secondary : colors.background,
        borderRadius: BorderRadius.circular(disc * 2),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.spacing.xs,
          theme.spacing.xs / 2,
          theme.spacing.sm,
          theme.spacing.xs / 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: disc,
              height: disc + 4,
              child: Stack(
                children: [
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      top: 4 - i * 2.0,
                      child: Container(
                        width: disc,
                        height: disc,
                        decoration: BoxDecoration(
                          color: palette.chip,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.chipEdge,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.xs),
            Flexible(
              child: Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  color: emphasized
                      ? colors.secondaryForeground
                      : colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The oval playing surface.
class TableFelt extends StatelessWidget {
  const TableFelt({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = TablePalette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.felt,
        shape: OvalBorder(side: BorderSide(color: palette.feltEdge, width: 3)),
      ),
      child: child,
    );
  }
}
