import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../import/import_flow.dart';
import '../library/library_cubit.dart';
import 'results_graph.dart';
import 'statistics_cubit.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryCubit>();
    return BlocProvider(
      create: (_) => StatisticsCubit(
        core: library.core,
        databasePath: library.databasePath,
      )..load(),
      child: BlocListener<LibraryCubit, LibraryState>(
        listenWhen: (previous, current) =>
            previous is LibraryReady &&
            current is LibraryReady &&
            previous.storedCount != current.storedCount,
        listener: (context, _) => context.read<StatisticsCubit>().load(),
        child: const _StatisticsContent(),
      ),
    );
  }
}

class _StatisticsContent extends StatefulWidget {
  const _StatisticsContent();

  @override
  State<_StatisticsContent> createState() => _StatisticsContentState();
}

class _StatisticsContentState extends State<_StatisticsContent> {
  bool _bigBlinds = false;

  String _playerKey(String room, String name) => '$room\u0000$name';

  Future<void> _showFilters() async {
    final cubit = context.read<StatisticsCubit>();
    final strings = context.app.localizations;
    var currency = cubit.currency;
    var from = cubit.dateFrom ?? '';
    var to = cubit.dateTo ?? '';
    String? validation;
    await showRiverOverlay<void>(
      context: context,
      title: strings.handsFilters,
      builder: (overlayContext) => StatefulBuilder(
        builder: (overlayContext, update) {
          final spacing = overlayContext.app.theme.spacing;
          Widget field(
            String label,
            String value,
            String hint,
            ValueChanged<String> onChanged,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: overlayContext.app.theme.textTheme.small),
              SizedBox(height: spacing.xs),
              ShadInput(
                initialValue: value,
                placeholder: Text(hint),
                onChanged: onChanged,
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field(
                strings.handsCurrency,
                currency,
                strings.handsCurrencyHint,
                (value) => currency = value,
              ),
              SizedBox(height: spacing.lg),
              field(
                strings.handsFromDate,
                from,
                '2026-01-01',
                (value) => from = value,
              ),
              SizedBox(height: spacing.lg),
              field(
                strings.handsToDate,
                to,
                '2026-12-31',
                (value) => to = value,
              ),
              if (validation != null) ...[
                SizedBox(height: spacing.md),
                Text(
                  validation!,
                  style: overlayContext.app.theme.textTheme.muted.copyWith(
                    color: overlayContext.app.theme.colors.destructive,
                  ),
                ),
              ],
              SizedBox(height: spacing.xl),
              Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  RiverButton(
                    label: strings.handsApplyFilters,
                    onPressed: () {
                      String? date(String value) {
                        final trimmed = value.trim();
                        return trimmed.isEmpty ? null : trimmed;
                      }

                      final fromDate = date(from);
                      final toDate = date(to);
                      final validDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if ((fromDate != null && !validDate.hasMatch(fromDate)) ||
                          (toDate != null && !validDate.hasMatch(toDate)) ||
                          (fromDate != null &&
                              toDate != null &&
                              fromDate.compareTo(toDate) > 0)) {
                        update(() => validation = strings.handsInvalidFilters);
                        return;
                      }
                      Navigator.of(overlayContext).pop();
                      cubit.applyFilters(
                        currency: currency,
                        dateFrom: fromDate,
                        dateTo: toDate,
                      );
                    },
                  ),
                  RiverButton(
                    label: strings.handsClearFilters,
                    variant: RiverButtonVariant.outline,
                    onPressed: () {
                      Navigator.of(overlayContext).pop();
                      cubit.clearFilters();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    return RiverPage(
      width: RiverPageWidth.wide,
      header: RiverPageHeader(
        title: strings.statisticsTitle,
        description: strings.statisticsDescription,
        actions: [
          RiverButton(
            label: strings.handsFilters,
            icon: LucideIcons.listFilter,
            variant: RiverButtonVariant.outline,
            onPressed: _showFilters,
          ),
          RiverButton(
            label: strings.statisticsRefresh,
            icon: LucideIcons.refreshCw,
            variant: RiverButtonVariant.outline,
            onPressed: () => context.read<StatisticsCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<StatisticsCubit, StatisticsState>(
        builder: (context, state) {
          final report = state.report;
          if (report == null && state.status == StatisticsStatus.loading) {
            return RiverStateView.loading(label: strings.statisticsLoading);
          }
          if (report == null && state.status == StatisticsStatus.failed) {
            return RiverStateView.error(
              title: strings.statisticsLoadFailedTitle,
              message: strings.statisticsLoadFailed,
              retryLabel: strings.retry,
              onRetry: context.read<StatisticsCubit>().load,
            );
          }
          if (report == null || report.selected == null) {
            return RiverStateView.empty(
              icon: LucideIcons.chartLine,
              title: strings.libraryEmptyTitle,
              description: strings.statisticsEmpty,
              action: RiverButton(
                label: strings.importAction,
                icon: LucideIcons.upload,
                onPressed: () => ImportFlow.start(context),
              ),
            );
          }
          final selected = report.selected!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.status == StatisticsStatus.loading)
                const ShadProgress(),
              if (state.status == StatisticsStatus.failed) ...[
                ShadAlert.destructive(
                  description: Text(strings.statisticsLoadFailed),
                ),
                SizedBox(height: context.app.theme.spacing.lg),
              ],
              _PlayerPicker(
                players: report.players,
                selected: selected,
                playerKey: _playerKey,
                onSelected: (room, name) =>
                    context.read<StatisticsCubit>().selectPlayer(room, name),
              ),
              SizedBox(height: context.app.theme.spacing.xl),
              _SummaryCards(selected: selected),
              SizedBox(height: context.app.theme.spacing.xl),
              _GraphCard(
                report: report,
                bigBlinds: _bigBlinds,
                onChanged: (value) => setState(() => _bigBlinds = value),
              ),
              SizedBox(height: context.app.theme.spacing.xl),
              _StatisticsTable(stats: selected.stats),
            ],
          );
        },
      ),
    );
  }
}

class _PlayerPicker extends StatelessWidget {
  const _PlayerPicker({
    required this.players,
    required this.selected,
    required this.playerKey,
    required this.onSelected,
  });

  final List<AnalyticsPlayer> players;
  final PlayerStatistics selected;
  final String Function(String room, String name) playerKey;
  final void Function(String room, String name) onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final selectedKey = playerKey(selected.room, selected.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.statisticsPlayer,
          style: context.app.theme.textTheme.small,
        ),
        SizedBox(height: context.app.theme.spacing.xs),
        SizedBox(
          width: 360,
          child: ShadSelect<String>(
            key: ValueKey(selectedKey),
            initialValue: selectedKey,
            options: [
              for (final player in players)
                ShadOption(
                  value: playerKey(player.room, player.name),
                  child: Text('${player.name} · ${player.room}'),
                ),
            ],
            selectedOptionBuilder: (context, value) {
              for (final player in players) {
                if (playerKey(player.room, player.name) == value) {
                  return Text('${player.name} · ${player.room}');
                }
              }
              return Text(selected.name);
            },
            onChanged: (value) {
              for (final player in players) {
                if (playerKey(player.room, player.name) == value) {
                  onSelected(player.room, player.name);
                  return;
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.selected});

  final PlayerStatistics selected;

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final core = [
      for (final key in [
        'vpip',
        'pfr',
        'three_bet',
        'fold_to_three_bet',
        'steal',
        'fold_bb_to_steal',
      ])
        selected.stats.firstWhere((stat) => stat.key == key),
    ];
    return Wrap(
      spacing: context.app.theme.spacing.lg,
      runSpacing: context.app.theme.spacing.lg,
      children: [
        _MetricCard(
          label: strings.statisticsHands,
          value: NumberFormat.decimalPattern().format(selected.hands),
        ),
        _MetricCard(
          label: strings.statisticsBb100,
          value: selected.bbPer100 == null
              ? strings.statisticsNoEvidence
              : NumberFormat('+0.00;-0.00').format(selected.bbPer100),
        ),
        _MetricCard(
          label: strings.statisticsAggressionFactor,
          value: selected.aggressionFactor == null
              ? strings.statisticsNoEvidence
              : NumberFormat('0.00').format(selected.aggressionFactor),
        ),
        for (final stat in core)
          _MetricCard(
            label: stat.label,
            value: _rate(stat),
            detail: strings.statisticsSample(stat.successes, stat.eligible),
          ),
        for (final result in selected.results)
          _MetricCard(
            label: strings.statisticsNetResult(result.currency),
            value: _money(result.net, result.currency, result.currencyScale),
            detail:
                '${strings.statisticsAtShowdown}: ${_money(result.netAtShowdown, result.currency, result.currencyScale)} · '
                '${strings.statisticsWithoutShowdown}: ${_money(result.netWithoutShowdown, result.currency, result.currencyScale)}',
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = context.app.theme;
    return ShadCard(
      width: 260,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.muted),
          SizedBox(height: theme.spacing.sm),
          Text(value, style: theme.textTheme.h3),
          if (detail != null) ...[
            SizedBox(height: theme.spacing.xs),
            Text(detail!, style: theme.textTheme.small),
          ],
        ],
      ),
    );
  }
}

class _GraphCard extends StatelessWidget {
  const _GraphCard({
    required this.report,
    required this.bigBlinds,
    required this.onChanged,
  });

  final PlayerAnalyticsReport report;
  final bool bigBlinds;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final currency = report.graphCurrency ?? '';
    final last = report.points.lastOrNull;
    return ShadCard(
      width: double.infinity,
      title: Text(strings.statisticsResultsGraph),
      description: Text(strings.statisticsGraphDescription),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children: [
              RiverButton(
                label: strings.statisticsShowCurrency(currency),
                variant: bigBlinds
                    ? RiverButtonVariant.outline
                    : RiverButtonVariant.primary,
                onPressed: () => onChanged(false),
              ),
              RiverButton(
                label: strings.statisticsShowBigBlinds,
                variant: bigBlinds
                    ? RiverButtonVariant.primary
                    : RiverButtonVariant.outline,
                onPressed: () => onChanged(true),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          if (report.points.isEmpty)
            Text(strings.statisticsNoGraph, style: theme.textTheme.muted)
          else ...[
            ResultsGraph(
              points: report.points,
              useBigBlinds: bigBlinds,
              semanticsLabel: bigBlinds
                  ? strings.statisticsBigBlindsGraphLabel
                  : strings.statisticsCurrencyGraphLabel(currency),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              bigBlinds
                  ? strings.statisticsFinalBigBlinds(
                      NumberFormat(
                        '+0.00;-0.00',
                      ).format(last!.cumulativeBigBlinds),
                    )
                  : strings.statisticsFinalCurrency(
                      _money(
                        last!.cumulativeNet,
                        currency,
                        report.graphCurrencyScale,
                      ),
                    ),
              style: theme.textTheme.p,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatisticsTable extends StatelessWidget {
  const _StatisticsTable({required this.stats});

  final List<StatisticValue> stats;

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    return ShadCard(
      width: double.infinity,
      title: Text(strings.statisticsAllHeading),
      description: Text(strings.statisticsSampleExplanation),
      content: Column(
        children: [
          for (final stat in stats)
            Container(
              padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.colors.border)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final description = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat.label, style: theme.textTheme.large),
                      SizedBox(height: theme.spacing.xs),
                      Text(stat.description, style: theme.textTheme.muted),
                    ],
                  );
                  final value = Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_rate(stat), style: theme.textTheme.h4),
                      Text(
                        strings.statisticsSample(stat.successes, stat.eligible),
                        style: theme.textTheme.muted,
                      ),
                      if (stat.eligible < stat.minimumMeaningfulSample)
                        Text(
                          strings.statisticsSmallSample,
                          style: theme.textTheme.small,
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        description,
                        SizedBox(height: theme.spacing.sm),
                        value,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: description),
                      SizedBox(width: theme.spacing.xl),
                      value,
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

String _rate(StatisticValue stat) =>
    stat.rate == null ? '—' : NumberFormat('0.0%').format(stat.rate);

String _money(int units, String currency, int scale) {
  final symbol = switch (currency) {
    'USD' => r'$',
    'EUR' => '€',
    _ => '$currency ',
  };
  final value = units / math.pow(10, scale);
  return NumberFormat.currency(
    symbol: symbol,
    decimalDigits: scale,
  ).format(value);
}
