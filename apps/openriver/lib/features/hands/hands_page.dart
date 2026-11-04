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

/// A bounded, newest-first view of imported hands.
class HandsPage extends StatefulWidget {
  const HandsPage({super.key});

  @override
  State<HandsPage> createState() => _HandsPageState();
}

class _HandsPageState extends State<HandsPage> {
  final _hands = <StoredHand>[];
  HandCursor? _next;
  int? _knownCount;
  int? _openingHand;
  int _request = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onLibraryState(context.read<LibraryCubit>().state);
    });
  }

  void _onLibraryState(LibraryState state) {
    if (state is LibraryReady &&
        !state.importing &&
        state.storedCount != _knownCount) {
      _knownCount = state.storedCount;
      _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _hands.clear();
        _next = null;
        _loaded = false;
      }
    });
    final library = context.read<LibraryCubit>();
    try {
      final page = await library.core.listHands(
        await library.databasePath(),
        cursor: _next,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _hands.addAll(page.hands);
        _next = page.nextCursor;
        _loading = false;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = context.app.localizations.handsLoadFailed;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final strings = context.app.localizations;
    final theme = context.app.theme;
    return BlocListener<LibraryCubit, LibraryState>(
      listener: (_, state) => _onLibraryState(state),
      child: RiverPage(
        width: RiverPageWidth.wide,
        header: RiverPageHeader(
          title: strings.handsTitle,
          description: strings.handsDescription,
          actions: [
            // Development entry until imported-hand replay is exercised widely.
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
            LibraryReady() => _content(theme),
          },
        ),
      ),
    );
  }

  Widget _content(RiverThemeAccess theme) {
    final strings = context.app.localizations;
    if (!_loaded && _loading) {
      return RiverStateView.loading(label: strings.handsLoading);
    }
    if (!_loaded && _error != null) {
      return RiverStateView.error(
        title: strings.handsLoadFailed,
        message: strings.handsLoadFailed,
        retryLabel: strings.retry,
        onRetry: () => _load(reset: true),
      );
    }
    final spacing = theme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          ShadAlert.destructive(
            icon: const Icon(LucideIcons.triangleAlert),
            description: Text(_error!),
          ),
          SizedBox(height: spacing.md),
        ],
        for (final hand in _hands) ...[
          _handCard(hand, theme),
          SizedBox(height: spacing.md),
        ],
        if (_error == null && (_next != null || _loading))
          Align(
            alignment: Alignment.center,
            child: RiverButton(
              label: _loading ? strings.handsLoading : strings.handsLoadMore,
              variant: RiverButtonVariant.outline,
              onPressed: _loading ? null : _load,
            ),
          ),
        if (_error != null && _hands.isNotEmpty && !_loading)
          Align(
            alignment: Alignment.center,
            child: RiverButton(
              label: strings.retry,
              variant: RiverButtonVariant.outline,
              onPressed: _load,
            ),
          ),
      ],
    );
  }

  Widget _handCard(StoredHand hand, RiverThemeAccess theme) {
    final strings = context.app.localizations;
    final date = DateTime.tryParse(hand.playedAt)?.toLocal();
    final played = date == null
        ? hand.playedAt
        : DateFormat.yMMMd().add_Hm().format(date);
    final small = ReplayFormat.currencyAmount(
      hand.smallBlind,
      hand.currency,
      hand.currencyScale,
    );
    final big = ReplayFormat.currencyAmount(
      hand.bigBlind,
      hand.currency,
      hand.currencyScale,
    );
    return ShadCard(
      width: double.infinity,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hand.tableName, style: theme.textTheme.h4),
          SizedBox(height: theme.spacing.xs),
          Text(
            strings.handsRowDetails(played, hand.room, hand.externalHandId),
            style: theme.textTheme.muted,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            strings.handsRowGame(small, big, hand.playerCount),
            style: theme.textTheme.p,
          ),
          SizedBox(height: theme.spacing.md),
          RiverButton(
            label: _openingHand == hand.id
                ? strings.handsOpeningReplay
                : strings.handsOpenReplay,
            icon: LucideIcons.play,
            variant: RiverButtonVariant.outline,
            onPressed: _openingHand == null ? () => _open(hand) : null,
          ),
        ],
      ),
    );
  }
}
