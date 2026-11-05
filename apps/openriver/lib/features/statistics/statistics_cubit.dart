import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openriver_api/openriver_api.dart';

enum StatisticsStatus { loading, ready, failed }

final class StatisticsState {
  const StatisticsState({required this.status, this.report});

  final StatisticsStatus status;
  final PlayerAnalyticsReport? report;
}

class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit({required this.core, required this.databasePath})
    : super(const StatisticsState(status: StatisticsStatus.loading));

  final OpenRiverCore core;
  final Future<String> Function() databasePath;

  String _room = '';
  String _player = '';
  String _currency = '';
  String? _dateFrom;
  String? _dateTo;
  int _revision = 0;

  String get currency => _currency;
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;

  Future<void> load() async {
    final revision = ++_revision;
    emit(
      StatisticsState(status: StatisticsStatus.loading, report: state.report),
    );
    try {
      final report = await core.playerAnalytics(
        await databasePath(),
        PlayerAnalyticsQuery(
          room: _room,
          player: _player,
          currency: _currency,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        ),
      );
      if (isClosed || revision != _revision) return;
      _room = report.selected?.room ?? '';
      _player = report.selected?.name ?? '';
      emit(StatisticsState(status: StatisticsStatus.ready, report: report));
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          StatisticsState(
            status: StatisticsStatus.failed,
            report: state.report,
          ),
        );
      }
    }
  }

  Future<void> selectPlayer(String room, String player) {
    _room = room;
    _player = player;
    return load();
  }

  Future<void> applyFilters({
    required String currency,
    required String? dateFrom,
    required String? dateTo,
  }) {
    _currency = currency.trim().toUpperCase();
    _dateFrom = dateFrom;
    _dateTo = dateTo;
    _room = '';
    _player = '';
    return load();
  }

  Future<void> clearFilters() =>
      applyFilters(currency: '', dateFrom: null, dateTo: null);
}
