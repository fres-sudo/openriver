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
