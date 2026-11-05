// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenRiver';

  @override
  String get navLibrary => 'Library';

  @override
  String get navHands => 'Hands';

  @override
  String get navStatistics => 'Statistics';

  @override
  String get navSettings => 'Settings';

  @override
  String get importAction => 'Import hand history';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryDescription =>
      'Post-session review, stored on this device. No account needed.';

  @override
  String get libraryOpening => 'Opening your library…';

  @override
  String get libraryOpenFailedTitle => 'Let’s try that again';

  @override
  String get retry => 'Try again';

  @override
  String get libraryReady => 'Your library is ready';

  @override
  String storedHands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stored hands',
      one: '1 stored hand',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptyTitle => 'No hands yet';

  @override
  String get libraryEmptyDescription =>
      'Import a hand history file exported after your session to start your library.';

  @override
  String get onboardingExport =>
      'In your poker room, request or save your own hand history after a session.';

  @override
  String get onboardingImport =>
      'Choose the text file here. Valid hands are stored locally; rejected hands include a reason.';

  @override
  String get onboardingReview =>
      'Open Statistics for results and tendencies, or Hands to search and replay each hand.';

  @override
  String get onboardingFormats =>
      'Supported input: PokerStars-style NLHE cash histories in English (USD) or Italian (EUR). Tournament hands are not imported.';

  @override
  String lastImport(int imported, int duplicates, int rejected) {
    return 'Last import: imported $imported, duplicates $duplicates, rejected $rejected.';
  }

  @override
  String get viewImportReport => 'View report';

  @override
  String get importTitle => 'Import hand history';

  @override
  String get importProgressLabel => 'Importing hands';

  @override
  String get importProgressUnknown => 'Importing hands…';

  @override
  String importProgress(int processed, int total) {
    return 'Importing hands… $processed of $total';
  }

  @override
  String get importContinuesHint =>
      'You can close this; the import keeps running.';

  @override
  String get cancelImport => 'Cancel import';

  @override
  String importSummary(int imported, int duplicates, int rejected) {
    return 'Imported $imported, duplicates $duplicates, rejected $rejected.';
  }

  @override
  String get importFailedTitle => 'The import did not finish';

  @override
  String get rejectedHandsHeading => 'Rejected hands';

  @override
  String rejectedHand(String handId, int startLine, int endLine, String code) {
    return 'Hand $handId, lines $startLine–$endLine: $code';
  }

  @override
  String get diagnosticUnsupported =>
      'This hand uses an unsupported game or format.';

  @override
  String get diagnosticIncomplete =>
      'The hand is incomplete, so it was not stored.';

  @override
  String get diagnosticMalformed =>
      'A required field could not be read with confidence.';

  @override
  String get diagnosticInvalid =>
      'The hand’s actions, cards, or payouts are inconsistent.';

  @override
  String get diagnosticDuplicate =>
      'The same hand ID appears more than once in this file.';

  @override
  String get unknownHand => 'unknown';

  @override
  String get chooseAnotherFile => 'Choose another file';

  @override
  String get done => 'Done';

  @override
  String get fileChooserFailed =>
      'The file chooser could not open. Please try again.';

  @override
  String get handsTitle => 'Hands';

  @override
  String get handsDescription => 'Every hand you have imported.';

  @override
  String get handsLoading => 'Loading hands…';

  @override
  String get handsLoadMore => 'Load more hands';

  @override
  String get handsLoadFailed => 'Hands could not be loaded. Please try again.';

  @override
  String get handsReplayFailed =>
      'This hand could not be opened. Please try again.';

  @override
  String get handsOpenReplay => 'Replay hand';

  @override
  String get handsOpeningReplay => 'Opening replay…';

  @override
  String get handsSearchHint => 'Search hands, tables, rooms, players…';

  @override
  String get handsFilters => 'Filters';

  @override
  String get handsColumns => 'Columns';

  @override
  String get handsSort => 'Sort';

  @override
  String get handsReset => 'Reset';

  @override
  String get handsApplyFilters => 'Apply filters';

  @override
  String get handsClearFilters => 'Clear filters';

  @override
  String get handsInvalidFilters =>
      'Check the date range and player counts, then try again.';

  @override
  String get handsRoom => 'Room';

  @override
  String get handsCurrency => 'Currency';

  @override
  String get handsCurrencyHint => 'USD';

  @override
  String get handsFromDate => 'From date (UTC)';

  @override
  String get handsToDate => 'To date (UTC)';

  @override
  String get handsMinPlayers => 'Minimum players';

  @override
  String get handsMaxPlayers => 'Maximum players';

  @override
  String get handsDate => 'Date';

  @override
  String get handsHandId => 'Hand ID';

  @override
  String get handsTable => 'Table';

  @override
  String get handsBlinds => 'Blinds';

  @override
  String get handsPlayers => 'Players';

  @override
  String get handsPot => 'Pot';

  @override
  String get handsSelectPage => 'Select all visible hands';

  @override
  String handsSelectHand(String handId) {
    return 'Select hand $handId';
  }

  @override
  String get handsNoResults => 'No matching hands';

  @override
  String get handsNoResultsHint => 'Try another search or change the filters.';

  @override
  String handsShowing(int first, int last, int total) {
    return 'Showing $first–$last of $total';
  }

  @override
  String handsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0 · Clear';
  }

  @override
  String handsRowsPerPage(int count) {
    return '$count rows per page';
  }

  @override
  String get handsRowsPerPageTitle => 'Rows per page';

  @override
  String handsPageOf(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String get handsFirstPage => 'First page';

  @override
  String get handsPreviousPage => 'Previous page';

  @override
  String get handsNextPage => 'Next page';

  @override
  String get handsLastPage => 'Last page';

  @override
  String handsRowDetails(String played, String room, String handId) {
    return '$played · $room · Hand #$handId';
  }

  @override
  String handsRowGame(String smallBlind, String bigBlind, int players) {
    String _temp0 = intl.Intl.pluralLogic(
      players,
      locale: localeName,
      other: '$players players',
      one: '1 player',
    );
    return 'Blinds $smallBlind/$bigBlind · $_temp0';
  }

  @override
  String get handsComingTitle => 'Browsing hands is coming';

  @override
  String handsComingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hands are stored.',
      one: '1 hand is stored.',
    );
    return '$_temp0 A searchable list arrives in a later version.';
  }

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get statisticsDescription =>
      'Results and tendencies calculated from your imported hands.';

  @override
  String get statisticsLoading => 'Calculating statistics…';

  @override
  String get statisticsLoadFailedTitle => 'Statistics could not be calculated';

  @override
  String get statisticsLoadFailed =>
      'Your hands are still stored. Try calculating the report again.';

  @override
  String get statisticsEmpty =>
      'Import hands to see results, a winnings graph, and core statistics.';

  @override
  String get statisticsRefresh => 'Refresh';

  @override
  String get statisticsPlayer => 'Player and room';

  @override
  String get statisticsHands => 'Hands';

  @override
  String get statisticsBb100 => 'BB / 100 hands';

  @override
  String get statisticsAggressionFactor => 'Aggression factor';

  @override
  String get statisticsNoEvidence => 'No evidence';

  @override
  String statisticsNetResult(String currency) {
    return 'Net result · $currency';
  }

  @override
  String get statisticsAtShowdown => 'At showdown';

  @override
  String get statisticsWithoutShowdown => 'Without showdown';

  @override
  String statisticsSample(int successes, int eligible) {
    return '$successes / $eligible opportunities';
  }

  @override
  String get statisticsResultsGraph => 'Cumulative results';

  @override
  String get statisticsGraphDescription =>
      'Chronological results for the selected player and filters. Large reports are sampled to 500 points, including the final result.';

  @override
  String statisticsShowCurrency(String currency) {
    return 'Show $currency';
  }

  @override
  String get statisticsShowBigBlinds => 'Show big blinds';

  @override
  String get statisticsNoGraph => 'No result points match these filters.';

  @override
  String statisticsCurrencyGraphLabel(String currency) {
    return 'Cumulative net result in $currency';
  }

  @override
  String get statisticsBigBlindsGraphLabel =>
      'Cumulative net result in big blinds';

  @override
  String statisticsFinalCurrency(String amount) {
    return 'Final result: $amount';
  }

  @override
  String statisticsFinalBigBlinds(String amount) {
    return 'Final result: $amount BB';
  }

  @override
  String get statisticsAllHeading => 'All core statistics';

  @override
  String get statisticsSampleExplanation =>
      'Rates show successes over eligible opportunities. A dash means no evidence, not zero percent.';

  @override
  String get statisticsSmallSample => 'Small sample';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDescription => 'About this copy of OpenRiver.';

  @override
  String get aboutHeading => 'About';

  @override
  String coreVersion(String version) {
    return 'Core version $version';
  }

  @override
  String schemaVersion(int version) {
    return 'Library schema $version';
  }

  @override
  String get privacyNote =>
      'Your hands stay on this device. OpenRiver needs no account or network connection.';

  @override
  String get exportHeading => 'Data export';

  @override
  String get exportDescription =>
      'Save a consistent SQLite backup of your library, including hands, import reports, and provenance. Keep the file somewhere safe.';

  @override
  String get exportAction => 'Export library backup';

  @override
  String exportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hands',
      one: '1 hand',
    );
    return 'Backup exported with $_temp0.';
  }

  @override
  String get exportDestinationExists =>
      'That file already exists. Choose a new filename so nothing is overwritten.';

  @override
  String get exportInvalidPath =>
      'The backup could not be saved there. Choose a different location.';

  @override
  String get exportFailed =>
      'The backup could not be completed. Check available storage and try again.';

  @override
  String get exportChooserFailed =>
      'The save dialog could not open. Please try again.';

  @override
  String get replayTitle => 'Hand replay';

  @override
  String get replaySampleAction => 'Open sample replay';

  @override
  String get replayClose => 'Close replay';

  @override
  String amountInBigBlinds(String value) {
    return '$value BB';
  }

  @override
  String get streetPreflop => 'Preflop';

  @override
  String get streetFlop => 'Flop';

  @override
  String get streetTurn => 'Turn';

  @override
  String get streetRiver => 'River';

  @override
  String get streetShowdown => 'Showdown';

  @override
  String get positionSmallBlindShort => 'SB';

  @override
  String get positionBigBlindShort => 'BB';

  @override
  String get positionUtgShort => 'UTG';

  @override
  String get positionUtg1Short => 'UTG+1';

  @override
  String get positionUtg2Short => 'UTG+2';

  @override
  String get positionUtg3Short => 'UTG+3';

  @override
  String get positionLojackShort => 'LJ';

  @override
  String get positionHijackShort => 'HJ';

  @override
  String get positionCutoffShort => 'CO';

  @override
  String get positionButtonShort => 'BTN';

  @override
  String get positionSmallBlind => 'small blind';

  @override
  String get positionBigBlind => 'big blind';

  @override
  String get positionUtg => 'under the gun';

  @override
  String get positionUtg1 => 'under the gun plus one';

  @override
  String get positionUtg2 => 'under the gun plus two';

  @override
  String get positionUtg3 => 'under the gun plus three';

  @override
  String get positionLojack => 'lojack';

  @override
  String get positionHijack => 'hijack';

  @override
  String get positionCutoff => 'cutoff';

  @override
  String get positionButton => 'button';

  @override
  String actionSmallBlind(String amount) {
    return 'SB $amount';
  }

  @override
  String actionBigBlind(String amount) {
    return 'BB $amount';
  }

  @override
  String actionAnte(String amount) {
    return 'Ante $amount';
  }

  @override
  String get actionFold => 'Fold';

  @override
  String get actionCheck => 'Check';

  @override
  String actionCall(String amount) {
    return 'Call $amount';
  }

  @override
  String actionBet(String amount) {
    return 'Bet $amount';
  }

  @override
  String actionRaiseTo(String amount) {
    return 'Raise to $amount';
  }

  @override
  String actionReturned(String amount) {
    return 'Returned $amount';
  }

  @override
  String get allIn => 'All-in';

  @override
  String eventStart(int count, String smallBlind, String bigBlind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players seated',
      one: '1 player seated',
    );
    return '$_temp0, blinds $smallBlind/$bigBlind';
  }

  @override
  String eventSmallBlind(String name, String amount) {
    return '$name posts small blind $amount';
  }

  @override
  String eventBigBlind(String name, String amount) {
    return '$name posts big blind $amount';
  }

  @override
  String eventAnte(String name, String amount) {
    return '$name posts ante $amount';
  }

  @override
  String eventFold(String name) {
    return '$name folds';
  }

  @override
  String eventCheck(String name) {
    return '$name checks';
  }

  @override
  String eventCall(String name, String amount) {
    return '$name calls $amount';
  }

  @override
  String eventBet(String name, String amount) {
    return '$name bets $amount';
  }

  @override
  String eventRaiseTo(String name, String amount) {
    return '$name raises to $amount';
  }

  @override
  String eventReturned(String name, String amount) {
    return '$name takes back $amount uncalled';
  }

  @override
  String eventAllIn(String action) {
    return '$action, all-in';
  }

  @override
  String eventStreet(String street, String cards) {
    return '$street: $cards';
  }

  @override
  String eventStreetNoCards(String street) {
    return '$street begins';
  }

  @override
  String get eventShowdown => 'Showdown';

  @override
  String eventAward(String name, String amount, String pot) {
    return '$name wins $amount from the $pot';
  }

  @override
  String get potMain => 'main pot';

  @override
  String potSide(int index) {
    return 'side pot $index';
  }

  @override
  String get potMainShort => 'Main';

  @override
  String potSideShort(int index) {
    return 'Side $index';
  }

  @override
  String potTotal(String amount) {
    return 'Pot $amount';
  }

  @override
  String potWithBets(String amount) {
    return 'Total $amount';
  }

  @override
  String seatFallbackName(int seat) {
    return 'Seat $seat';
  }

  @override
  String seatEmpty(int seat) {
    return 'Seat $seat, empty';
  }

  @override
  String seatSummary(int seat, String name) {
    return 'Seat $seat, $name';
  }

  @override
  String seatStack(String amount) {
    return 'stack $amount';
  }

  @override
  String seatBet(String amount) {
    return 'bet $amount';
  }

  @override
  String seatWon(String amount) {
    return 'won $amount';
  }

  @override
  String get seatFolded => 'folded';

  @override
  String get seatAllIn => 'all-in';

  @override
  String get seatToAct => 'to act';

  @override
  String get seatDealer => 'dealer button';

  @override
  String seatHolding(String cards) {
    return 'holding $cards';
  }

  @override
  String wonBadge(String amount) {
    return 'Won $amount';
  }

  @override
  String get dealerButton => 'D';

  @override
  String get rankJack => 'jack';

  @override
  String get rankQueen => 'queen';

  @override
  String get rankKing => 'king';

  @override
  String get rankAce => 'ace';

  @override
  String cardClubs(String rank) {
    return '$rank of clubs';
  }

  @override
  String cardDiamonds(String rank) {
    return '$rank of diamonds';
  }

  @override
  String cardHearts(String rank) {
    return '$rank of hearts';
  }

  @override
  String cardSpades(String rank) {
    return '$rank of spades';
  }

  @override
  String get cardFaceDown => 'face-down card';

  @override
  String get replayFirst => 'First step';

  @override
  String get replayPrevious => 'Previous step';

  @override
  String get replayPlay => 'Play';

  @override
  String get replayPause => 'Pause';

  @override
  String get replayNext => 'Next step';

  @override
  String get replayLast => 'Last step';

  @override
  String replayStepOf(int step, int count) {
    return 'Step $step of $count';
  }

  @override
  String get replayScrubber => 'Step';

  @override
  String get replaySpeed => 'Speed';

  @override
  String replaySpeedValue(String speed) {
    return '$speed×';
  }

  @override
  String get replayAmountsInBigBlinds => 'Amounts in big blinds';

  @override
  String get replayHideOpponentCards => 'Hide opponents’ cards until showdown';

  @override
  String get replayActionLog => 'Actions';

  @override
  String get replayShowActionLog => 'Show actions';
}
