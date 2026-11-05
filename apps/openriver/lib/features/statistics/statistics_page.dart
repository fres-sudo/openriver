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
