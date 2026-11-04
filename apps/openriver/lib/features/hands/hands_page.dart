import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:openriver_ui/openriver_ui.dart';

import '../../app/app_context.dart';
import '../import/import_flow.dart';
import '../library/library_cubit.dart';
import '../replay/replay_decode.dart';
import '../replay/replay_fixtures.dart';
import '../replay/replay_format.dart';
import '../replay/replay_view.dart';

/// Server-paged hand browser with the same table controls on desktop and mobile.
class HandsPage extends StatefulWidget {
  const HandsPage({super.key});

  @override
  State<HandsPage> createState() => _HandsPageState();
}

class _HandsPageState extends State<HandsPage> {
  final _searchController = TextEditingController();
  final _selected = <int>{};
  final _visible = HandSortColumn.values.toSet();
  Timer? _searchDebounce;
  List<StoredHand> _hands = const [];
  int? _knownCount;
  int? _openingHand;
  int _request = 0;
  int _total = 0;
  int _page = 0;
  int _pageSize = 20;
  HandSortColumn _sort = HandSortColumn.playedAt;
  bool _descending = true;
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  String _search = '';
  String _room = '';
  String _currency = '';
  String? _dateFrom;
  String? _dateTo;
  int? _minPlayers;
  int? _maxPlayers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onLibraryState(context.read<LibraryCubit>().state);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onLibraryState(LibraryState state) {
    if (state is LibraryReady &&
        !state.importing &&
        state.storedCount != _knownCount) {
      _knownCount = state.storedCount;
      _page = 0;
      _load();
    }
  }

  HandSearchQuery get _query => HandSearchQuery(
    search: _search,
    room: _room,
    currency: _currency,
    dateFrom: _dateFrom,
    dateTo: _dateTo,
    minPlayers: _minPlayers,
    maxPlayers: _maxPlayers,
    sort: _sort,
    descending: _descending,
    page: _page,
    pageSize: _pageSize,
  );

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    final library = context.read<LibraryCubit>();
    try {
      final result = await library.core.searchHands(
        await library.databasePath(),
        _query,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _hands = result.hands;
        _total = result.total;
        _loading = false;
        _loaded = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final scroll = PrimaryScrollController.maybeOf(context);
        if (scroll?.hasClients ?? false) scroll!.jumpTo(0);
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = context.app.localizations.handsLoadFailed;
      });
    }
  }

  void _onSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || value.trim() == _search) return;
      setState(() {
        _search = value.trim();
        _page = 0;
      });
      _load();
    });
  }

  void _changeSort(HandSortColumn column) {
    setState(() {
      if (_sort == column) {
        _descending = !_descending;
      } else {
        _sort = column;
        _descending = column == HandSortColumn.playedAt;
      }
      _page = 0;
    });
    _load();
  }

  void _changePage(int page) {
    final pages = math.max(1, (_total + _pageSize - 1) ~/ _pageSize);
    if (page < 0 || page >= pages || page == _page) return;
    setState(() => _page = page);
    _load();
  }

  void _clearAll() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _room = '';
      _currency = '';
      _dateFrom = null;
      _dateTo = null;
      _minPlayers = null;
      _maxPlayers = null;
      _page = 0;
    });
    _load();
  }

  bool get _hasFilters =>
      _search.isNotEmpty ||
      _room.isNotEmpty ||
      _currency.isNotEmpty ||
      _dateFrom != null ||
      _dateTo != null ||
      _minPlayers != null ||
      _maxPlayers != null;

  Future<void> _open(StoredHand hand) async {
    if (_openingHand != null) return;
    setState(() {
      _openingHand = hand.id;
      _error = null;
    });
    final library = context.read<LibraryCubit>();
    try {
      final json = await library.core.handReplayJson(
        await library.databasePath(),
        hand.id,
      );
      final replay = decodeReplay(json);
      if (!mounted) return;
      setState(() => _openingHand = null);
      await Navigator.of(context).push(ReplayView.route(replay));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _openingHand = null;
        _error = context.app.localizations.handsReplayFailed;
      });
    }
  }

  Future<void> _showFilters() async {
    final strings = context.app.localizations;
    var room = _room;
    var currency = _currency;
    var from = _dateFrom ?? '';
    var to = _dateTo ?? '';
    var minPlayers = _minPlayers?.toString() ?? '';
    var maxPlayers = _maxPlayers?.toString() ?? '';
    String? validation;
    await showRiverOverlay<void>(
      context: context,
      title: strings.handsFilters,
      builder: (overlayContext) => StatefulBuilder(
        builder: (overlayContext, update) {
          Widget field(
            String label,
            String value,
            ValueChanged<String> onChanged, {
            String? hint,
          }) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: overlayContext.app.theme.textTheme.small),
              SizedBox(height: overlayContext.app.theme.spacing.xs),
              ShadInput(
                initialValue: value,
                placeholder: hint == null ? null : Text(hint),
                onChanged: onChanged,
              ),
            ],
          );
          final spacing = overlayContext.app.theme.spacing;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field(strings.handsRoom, room, (v) => room = v),
              SizedBox(height: spacing.md),
              field(
                strings.handsCurrency,
                currency,
                (v) => currency = v,
                hint: strings.handsCurrencyHint,
              ),
              SizedBox(height: spacing.md),
              field(
                strings.handsFromDate,
                from,
                (v) => from = v,
                hint: 'YYYY-MM-DD',
              ),
              SizedBox(height: spacing.md),
              field(strings.handsToDate, to, (v) => to = v, hint: 'YYYY-MM-DD'),
              SizedBox(height: spacing.md),
              field(
                strings.handsMinPlayers,
                minPlayers,
                (v) => minPlayers = v,
                hint: '2',
              ),
              SizedBox(height: spacing.md),
              field(
                strings.handsMaxPlayers,
                maxPlayers,
                (v) => maxPlayers = v,
                hint: '10',
              ),
              if (validation != null) ...[
                SizedBox(height: spacing.md),
                ShadAlert.destructive(description: Text(validation!)),
              ],
              SizedBox(height: spacing.xl),
              Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  RiverButton(
                    label: strings.handsApplyFilters,
                    onPressed: () {
                      final min = int.tryParse(minPlayers.trim());
                      final max = int.tryParse(maxPlayers.trim());
                      if (!_validDate(from) ||
                          !_validDate(to) ||
                          (from.isNotEmpty &&
                              to.isNotEmpty &&
                              from.compareTo(to) > 0) ||
                          (minPlayers.trim().isNotEmpty && min == null) ||
                          (maxPlayers.trim().isNotEmpty && max == null) ||
                          (min != null && (min < 2 || min > 10)) ||
                          (max != null && (max < 2 || max > 10)) ||
                          (min != null && max != null && min > max)) {
                        update(() => validation = strings.handsInvalidFilters);
                        return;
                      }
                      setState(() {
                        _room = room.trim();
                        _currency = currency.trim().toUpperCase();
                        _dateFrom = from.trim().isEmpty ? null : from.trim();
                        _dateTo = to.trim().isEmpty ? null : to.trim();
                        _minPlayers = min;
                        _maxPlayers = max;
                        _page = 0;
                      });
                      Navigator.of(overlayContext).pop();
                      _load();
                    },
                  ),
                  RiverButton(
                    label: strings.handsClearFilters,
                    variant: RiverButtonVariant.outline,
                    onPressed: () {
                      Navigator.of(overlayContext).pop();
                      _clearAll();
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

  static bool _validDate(String input) {
    final value = input.trim();
    if (value.isEmpty) return true;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final date = DateTime.tryParse(value);
    return date != null && DateFormat('yyyy-MM-dd').format(date) == value;
  }

  Future<void> _showColumns() async {
    final strings = context.app.localizations;
    await showRiverOverlay<void>(
      context: context,
      title: strings.handsColumns,
      builder: (overlayContext) => StatefulBuilder(
        builder: (overlayContext, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final column in HandSortColumn.values)
              RiverButton(
                label: _columnLabel(column),
                icon: _visible.contains(column)
                    ? LucideIcons.check
                    : LucideIcons.plus,
                variant: RiverButtonVariant.ghost,
                onPressed: () {
                  if (_visible.length == 1 && _visible.contains(column)) return;
                  setState(() {
                    if (!_visible.add(column)) _visible.remove(column);
                  });
                  update(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSort() async {
    final strings = context.app.localizations;
    await showRiverOverlay<void>(
      context: context,
      title: strings.handsSort,
      builder: (overlayContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in HandSortColumn.values)
            RiverButton(
              label: _columnLabel(column),
              icon: _sort == column
                  ? (_descending ? LucideIcons.arrowDown : LucideIcons.arrowUp)
                  : LucideIcons.arrowUpDown,
              variant: RiverButtonVariant.ghost,
              onPressed: () {
                Navigator.of(overlayContext).pop();
                _changeSort(column);
              },
            ),
        ],
      ),
    );
  }

  String _columnLabel(HandSortColumn column) {
    final strings = context.app.localizations;
    return switch (column) {
      HandSortColumn.playedAt => strings.handsDate,
      HandSortColumn.handId => strings.handsHandId,
      HandSortColumn.table => strings.handsTable,
      HandSortColumn.room => strings.handsRoom,
      HandSortColumn.blinds => strings.handsBlinds,
      HandSortColumn.players => strings.handsPlayers,
      HandSortColumn.pot => strings.handsPot,
    };
  }

  String _date(StoredHand hand) {
    final date = DateTime.tryParse(hand.playedAt)?.toLocal();
    return date == null
        ? hand.playedAt
        : DateFormat.yMMMd().add_Hm().format(date);
  }

  String _amount(StoredHand hand, int units) =>
      ReplayFormat.currencyAmount(units, hand.currency, hand.currencyScale);

  List<RiverDataColumn<StoredHand>> _columns() => [
    for (final column in HandSortColumn.values)
      if (_visible.contains(column))
        RiverDataColumn<StoredHand>(
          id: column.name,
          label: _columnLabel(column),
          flex: switch (column) {
            HandSortColumn.playedAt => 2,
            HandSortColumn.table => 2,
            _ => 1,
          },
          cell: (context, hand) => Text(switch (column) {
            HandSortColumn.playedAt => _date(hand),
            HandSortColumn.handId => hand.externalHandId,
            HandSortColumn.table => hand.tableName,
            HandSortColumn.room => hand.room,
            HandSortColumn.blinds =>
              '${_amount(hand, hand.smallBlind)} / ${_amount(hand, hand.bigBlind)}',
            HandSortColumn.players => hand.playerCount.toString(),
            HandSortColumn.pot => _amount(hand, hand.totalPot),
          }),
        ),
  ];

  Widget _compactHand(
    BuildContext context,
    StoredHand hand,
    bool selected,
    VoidCallback onSelect,
    VoidCallback onOpen,
  ) {
    final theme = context.app.theme;
    final strings = context.app.localizations;
    final spacing = theme.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: ShadCard(
        width: double.infinity,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Semantics(
                      label: strings.handsSelectHand(hand.externalHandId),
                      checked: selected,
                      onTap: onSelect,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onSelect,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: ShadCheckbox(
                              value: selected,
                              onChanged: (_) => onSelect(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(hand.tableName, style: theme.textTheme.h4),
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Text(
              strings.handsRowDetails(
                _date(hand),
                hand.room,
                hand.externalHandId,
              ),
              style: theme.textTheme.muted,
            ),
            SizedBox(height: spacing.xs),
            Text(
              strings.handsRowGame(
                _amount(hand, hand.smallBlind),
                _amount(hand, hand.bigBlind),
                hand.playerCount,
              ),
              style: theme.textTheme.p,
            ),
            SizedBox(height: spacing.xs),
            Text(
              '${strings.handsPot}: ${_amount(hand, hand.totalPot)}',
              style: theme.textTheme.p,
            ),
            SizedBox(height: spacing.md),
            RiverButton(
              label: _openingHand == hand.id
                  ? strings.handsOpeningReplay
                  : strings.handsOpenReplay,
              icon: LucideIcons.play,
              variant: RiverButtonVariant.outline,
              onPressed: _openingHand == null ? onOpen : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    return BlocListener<LibraryCubit, LibraryState>(
      listener: (_, state) => _onLibraryState(state),
      child: RiverPage(
        width: RiverPageWidth.wide,
        header: RiverPageHeader(
          title: strings.handsTitle,
          description: strings.handsDescription,
          actions: [
            if (kDebugMode)
              RiverButton(
                label: strings.replaySampleAction,
                icon: LucideIcons.play,
                variant: RiverButtonVariant.outline,
                onPressed: () => Navigator.of(
                  context,
                ).push(ReplayView.route(ReplayFixtures.sixMaxRiver)),
              ),
          ],
        ),
        body: BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, state) => switch (state) {
            LibraryLoading() => RiverStateView.loading(
              label: strings.libraryOpening,
            ),
            LibraryFailed(:final message) => RiverStateView.error(
              title: strings.libraryOpenFailedTitle,
              message: message,
              retryLabel: strings.retry,
              onRetry: context.read<LibraryCubit>().open,
            ),
            LibraryReady(storedCount: 0, importing: false) =>
              RiverStateView.empty(
                icon: LucideIcons.inbox,
                title: strings.libraryEmptyTitle,
                description: strings.libraryEmptyDescription,
                action: RiverButton(
                  label: strings.importAction,
                  icon: LucideIcons.upload,
                  onPressed: () => ImportFlow.start(context),
                ),
              ),
            LibraryReady(storedCount: 0, importing: true) =>
              RiverStateView.loading(label: strings.importProgressUnknown),
            LibraryReady() => _content(),
          },
        ),
      ),
    );
  }

  Widget _content() {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final spacing = theme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: math.min(320, constraints.maxWidth),
                child: Semantics(
                  label: strings.handsSearchHint,
                  child: ShadInput(
                    controller: _searchController,
                    placeholder: Text(strings.handsSearchHint),
                    onChanged: _onSearch,
                  ),
                ),
              ),
              RiverButton(
                label: strings.handsFilters,
                icon: LucideIcons.listFilter,
                variant: RiverButtonVariant.outline,
                onPressed: _showFilters,
              ),
              RiverButton(
                label: strings.handsColumns,
                icon: LucideIcons.columns3,
                variant: RiverButtonVariant.outline,
                onPressed: _showColumns,
              ),
              RiverButton(
                label: strings.handsSort,
                icon: LucideIcons.arrowUpDown,
                variant: RiverButtonVariant.outline,
                onPressed: _showSort,
              ),
              if (_hasFilters)
                RiverButton(
                  label: strings.handsReset,
                  icon: LucideIcons.x,
                  variant: RiverButtonVariant.ghost,
                  onPressed: _clearAll,
                ),
              if (_selected.isNotEmpty)
                RiverButton(
                  label: strings.handsSelected(_selected.length),
                  variant: RiverButtonVariant.ghost,
                  onPressed: () => setState(_selected.clear),
                ),
            ],
          ),
        ),
        SizedBox(height: spacing.lg),
        if (_error != null) ...[
          ShadAlert.destructive(
            icon: const Icon(LucideIcons.triangleAlert),
            description: Text(_error!),
          ),
          SizedBox(height: spacing.md),
          RiverButton(
            label: strings.retry,
            variant: RiverButtonVariant.outline,
            onPressed: _load,
          ),
        ],
        if (!_loaded && _loading)
          RiverStateView.loading(label: strings.handsLoading)
        else if (_loaded && _hands.isEmpty && !_loading)
          RiverStateView.empty(
            icon: LucideIcons.searchX,
            title: strings.handsNoResults,
            description: strings.handsNoResultsHint,
          )
        else ...[
          RiverDataTable<StoredHand, int>(
            rows: _hands,
            columns: _columns(),
            keyOf: (hand) => hand.id,
            labelOf: (hand) => hand.externalHandId,
            selected: _selected,
            onSelectionChanged: (value) => setState(() {
              _selected
                ..clear()
                ..addAll(value);
            }),
            sortId: _sort.name,
            descending: _descending,
            onSort: (id) => _changeSort(HandSortColumn.values.byName(id)),
            onOpen: _open,
            openLabel: strings.handsOpenReplay,
            selectPageLabel: strings.handsSelectPage,
            selectRowLabel: (hand) =>
                strings.handsSelectHand(hand.externalHandId),
            compactBuilder: _compactHand,
          ),
          SizedBox(height: spacing.lg),
          _footer(),
        ],
      ],
    );
  }

  Widget _footer() {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    final pages = math.max(1, (_total + _pageSize - 1) ~/ _pageSize);
    final first = _total == 0 ? 0 : _page * _pageSize + 1;
    final last = math.min(_total, (_page + 1) * _pageSize);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.sm,
      children: [
        Text(
          strings.handsShowing(first, last, _total),
          style: theme.textTheme.muted,
        ),
        RiverButton(
          label: strings.handsRowsPerPage(_pageSize),
          variant: RiverButtonVariant.outline,
          onPressed: () => showRiverOverlay<void>(
            context: context,
            title: strings.handsRowsPerPageTitle,
            builder: (overlayContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final size in [10, 20, 30, 50])
                  RiverButton(
                    label: strings.handsRowsPerPage(size),
                    icon: _pageSize == size ? LucideIcons.check : null,
                    variant: RiverButtonVariant.ghost,
                    onPressed: () {
                      Navigator.of(overlayContext).pop();
                      setState(() {
                        _pageSize = size;
                        _page = 0;
                      });
                      _load();
                    },
                  ),
              ],
            ),
          ),
        ),
        Text(
          strings.handsPageOf(_page + 1, pages),
          style: theme.textTheme.muted,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RiverIconButton(
              icon: LucideIcons.chevronsLeft,
              label: strings.handsFirstPage,
              mirrorInRtl: true,
              onPressed: _loading || _page == 0 ? null : () => _changePage(0),
            ),
            RiverIconButton(
              icon: LucideIcons.chevronLeft,
              label: strings.handsPreviousPage,
              mirrorInRtl: true,
              onPressed: _loading || _page == 0
                  ? null
                  : () => _changePage(_page - 1),
            ),
            RiverIconButton(
              icon: LucideIcons.chevronRight,
              label: strings.handsNextPage,
              mirrorInRtl: true,
              onPressed: _loading || _page >= pages - 1
                  ? null
                  : () => _changePage(_page + 1),
            ),
            RiverIconButton(
              icon: LucideIcons.chevronsRight,
              label: strings.handsLastPage,
              mirrorInRtl: true,
              onPressed: _loading || _page >= pages - 1
                  ? null
                  : () => _changePage(pages - 1),
            ),
          ],
        ),
      ],
    );
  }
}
