import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenRiver'**
  String get appTitle;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navHands.
  ///
  /// In en, this message translates to:
  /// **'Hands'**
  String get navHands;

  /// No description provided for @navStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navStatistics;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Shell primary action and empty-state button that opens the file chooser.
  ///
  /// In en, this message translates to:
  /// **'Import hand history'**
  String get importAction;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @libraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Post-session review, stored on this device. No account needed.'**
  String get libraryDescription;

  /// No description provided for @libraryOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening your library…'**
  String get libraryOpening;

  /// No description provided for @libraryOpenFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Let’s try that again'**
  String get libraryOpenFailedTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @libraryReady.
  ///
  /// In en, this message translates to:
  /// **'Your library is ready'**
  String get libraryReady;

  /// No description provided for @storedHands.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stored hand} other{{count} stored hands}}'**
  String storedHands(int count);

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No hands yet'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Import a hand history file exported after your session to start your library.'**
  String get libraryEmptyDescription;

  /// No description provided for @onboardingExport.
  ///
  /// In en, this message translates to:
  /// **'In your poker room, request or save your own hand history after a session.'**
  String get onboardingExport;

  /// No description provided for @onboardingImport.
  ///
  /// In en, this message translates to:
  /// **'Choose the text file here. Valid hands are stored locally; rejected hands include a reason.'**
  String get onboardingImport;

  /// No description provided for @onboardingReview.
  ///
  /// In en, this message translates to:
  /// **'Open Statistics for results and tendencies, or Hands to search and replay each hand.'**
  String get onboardingReview;

  /// No description provided for @onboardingFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported input: PokerStars-style NLHE cash histories in English (USD) or Italian (EUR). Tournament hands are not imported.'**
  String get onboardingFormats;

  /// No description provided for @lastImport.
  ///
  /// In en, this message translates to:
  /// **'Last import: imported {imported}, duplicates {duplicates}, rejected {rejected}.'**
  String lastImport(int imported, int duplicates, int rejected);

  /// No description provided for @viewImportReport.
  ///
  /// In en, this message translates to:
  /// **'View report'**
  String get viewImportReport;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import hand history'**
  String get importTitle;

  /// No description provided for @importProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Importing hands'**
  String get importProgressLabel;

  /// No description provided for @importProgressUnknown.
  ///
  /// In en, this message translates to:
  /// **'Importing hands…'**
  String get importProgressUnknown;

  /// No description provided for @importProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing hands… {processed} of {total}'**
  String importProgress(int processed, int total);

  /// No description provided for @importContinuesHint.
  ///
  /// In en, this message translates to:
  /// **'You can close this; the import keeps running.'**
  String get importContinuesHint;

  /// No description provided for @cancelImport.
  ///
  /// In en, this message translates to:
  /// **'Cancel import'**
  String get cancelImport;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported}, duplicates {duplicates}, rejected {rejected}.'**
  String importSummary(int imported, int duplicates, int rejected);

  /// No description provided for @importFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The import did not finish'**
  String get importFailedTitle;

  /// No description provided for @rejectedHandsHeading.
  ///
  /// In en, this message translates to:
  /// **'Rejected hands'**
  String get rejectedHandsHeading;

  /// One rejected hand. {code} is the parser's stable diagnostic code.
  ///
  /// In en, this message translates to:
  /// **'Hand {handId}, lines {startLine}–{endLine}: {code}'**
  String rejectedHand(String handId, int startLine, int endLine, String code);

  /// No description provided for @diagnosticUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This hand uses an unsupported game or format.'**
  String get diagnosticUnsupported;

  /// No description provided for @diagnosticIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The hand is incomplete, so it was not stored.'**
  String get diagnosticIncomplete;

  /// No description provided for @diagnosticMalformed.
  ///
  /// In en, this message translates to:
  /// **'A required field could not be read with confidence.'**
  String get diagnosticMalformed;

  /// No description provided for @diagnosticInvalid.
  ///
  /// In en, this message translates to:
  /// **'The hand’s actions, cards, or payouts are inconsistent.'**
  String get diagnosticInvalid;

  /// No description provided for @diagnosticDuplicate.
  ///
  /// In en, this message translates to:
  /// **'The same hand ID appears more than once in this file.'**
  String get diagnosticDuplicate;

  /// No description provided for @unknownHand.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknownHand;

  /// No description provided for @chooseAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get chooseAnotherFile;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @fileChooserFailed.
  ///
  /// In en, this message translates to:
  /// **'The file chooser could not open. Please try again.'**
  String get fileChooserFailed;

  /// No description provided for @handsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hands'**
  String get handsTitle;

  /// No description provided for @handsDescription.
  ///
  /// In en, this message translates to:
  /// **'Every hand you have imported.'**
  String get handsDescription;

  /// No description provided for @handsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading hands…'**
  String get handsLoading;

  /// No description provided for @handsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more hands'**
  String get handsLoadMore;

  /// No description provided for @handsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Hands could not be loaded. Please try again.'**
  String get handsLoadFailed;

  /// No description provided for @handsReplayFailed.
  ///
  /// In en, this message translates to:
  /// **'This hand could not be opened. Please try again.'**
  String get handsReplayFailed;

  /// No description provided for @handsOpenReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay hand'**
  String get handsOpenReplay;

  /// No description provided for @handsOpeningReplay.
  ///
  /// In en, this message translates to:
  /// **'Opening replay…'**
  String get handsOpeningReplay;

  /// No description provided for @handsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search hands, tables, rooms, players…'**
  String get handsSearchHint;

  /// No description provided for @handsFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get handsFilters;

  /// No description provided for @handsColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get handsColumns;

  /// No description provided for @handsSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get handsSort;

  /// No description provided for @handsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get handsReset;

  /// No description provided for @handsApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get handsApplyFilters;

  /// No description provided for @handsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get handsClearFilters;

  /// No description provided for @handsInvalidFilters.
  ///
  /// In en, this message translates to:
  /// **'Check the date range and player counts, then try again.'**
  String get handsInvalidFilters;

  /// No description provided for @handsRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get handsRoom;

  /// No description provided for @handsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get handsCurrency;

  /// No description provided for @handsCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'USD'**
  String get handsCurrencyHint;

  /// No description provided for @handsFromDate.
  ///
  /// In en, this message translates to:
  /// **'From date (UTC)'**
  String get handsFromDate;

  /// No description provided for @handsToDate.
  ///
  /// In en, this message translates to:
  /// **'To date (UTC)'**
  String get handsToDate;

  /// No description provided for @handsMinPlayers.
  ///
  /// In en, this message translates to:
  /// **'Minimum players'**
  String get handsMinPlayers;

  /// No description provided for @handsMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'Maximum players'**
  String get handsMaxPlayers;

  /// No description provided for @handsDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get handsDate;

  /// No description provided for @handsHandId.
  ///
  /// In en, this message translates to:
  /// **'Hand ID'**
  String get handsHandId;

  /// No description provided for @handsTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get handsTable;

  /// No description provided for @handsBlinds.
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get handsBlinds;

  /// No description provided for @handsPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get handsPlayers;

  /// No description provided for @handsPot.
  ///
  /// In en, this message translates to:
  /// **'Pot'**
  String get handsPot;

  /// No description provided for @handsSelectPage.
  ///
  /// In en, this message translates to:
  /// **'Select all visible hands'**
  String get handsSelectPage;

  /// No description provided for @handsSelectHand.
  ///
  /// In en, this message translates to:
  /// **'Select hand {handId}'**
  String handsSelectHand(String handId);

  /// No description provided for @handsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching hands'**
  String get handsNoResults;

  /// No description provided for @handsNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try another search or change the filters.'**
  String get handsNoResultsHint;

  /// No description provided for @handsShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {first}–{last} of {total}'**
  String handsShowing(int first, int last, int total);

  /// No description provided for @handsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}} · Clear'**
  String handsSelected(int count);

  /// No description provided for @handsRowsPerPage.
  ///
  /// In en, this message translates to:
  /// **'{count} rows per page'**
  String handsRowsPerPage(int count);

  /// No description provided for @handsRowsPerPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Rows per page'**
  String get handsRowsPerPageTitle;

  /// No description provided for @handsPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String handsPageOf(int page, int pages);

  /// No description provided for @handsFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get handsFirstPage;

  /// No description provided for @handsPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get handsPreviousPage;

  /// No description provided for @handsNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get handsNextPage;

  /// No description provided for @handsLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get handsLastPage;

  /// No description provided for @handsRowDetails.
  ///
  /// In en, this message translates to:
  /// **'{played} · {room} · Hand #{handId}'**
  String handsRowDetails(String played, String room, String handId);

  /// No description provided for @handsRowGame.
  ///
  /// In en, this message translates to:
  /// **'Blinds {smallBlind}/{bigBlind} · {players, plural, =1{1 player} other{{players} players}}'**
  String handsRowGame(String smallBlind, String bigBlind, int players);

  /// No description provided for @handsComingTitle.
  ///
  /// In en, this message translates to:
  /// **'Browsing hands is coming'**
  String get handsComingTitle;

  /// No description provided for @handsComingDescription.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hand is stored.} other{{count} hands are stored.}} A searchable list arrives in a later version.'**
  String handsComingDescription(int count);

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @statisticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Results and tendencies calculated from your imported hands.'**
  String get statisticsDescription;

  /// No description provided for @statisticsLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating statistics…'**
  String get statisticsLoading;

  /// No description provided for @statisticsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics could not be calculated'**
  String get statisticsLoadFailedTitle;

  /// No description provided for @statisticsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your hands are still stored. Try calculating the report again.'**
  String get statisticsLoadFailed;

  /// No description provided for @statisticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Import hands to see results, a winnings graph, and core statistics.'**
  String get statisticsEmpty;

  /// No description provided for @statisticsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get statisticsRefresh;

  /// No description provided for @statisticsPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player and room'**
  String get statisticsPlayer;

  /// No description provided for @statisticsHands.
  ///
  /// In en, this message translates to:
  /// **'Hands'**
  String get statisticsHands;

  /// No description provided for @statisticsBb100.
  ///
  /// In en, this message translates to:
  /// **'BB / 100 hands'**
  String get statisticsBb100;

  /// No description provided for @statisticsAggressionFactor.
  ///
  /// In en, this message translates to:
  /// **'Aggression factor'**
  String get statisticsAggressionFactor;

  /// No description provided for @statisticsNoEvidence.
  ///
  /// In en, this message translates to:
  /// **'No evidence'**
  String get statisticsNoEvidence;

  /// No description provided for @statisticsNetResult.
  ///
  /// In en, this message translates to:
  /// **'Net result · {currency}'**
  String statisticsNetResult(String currency);

  /// No description provided for @statisticsAtShowdown.
  ///
  /// In en, this message translates to:
  /// **'At showdown'**
  String get statisticsAtShowdown;

  /// No description provided for @statisticsWithoutShowdown.
  ///
  /// In en, this message translates to:
  /// **'Without showdown'**
  String get statisticsWithoutShowdown;

  /// No description provided for @statisticsSample.
  ///
  /// In en, this message translates to:
  /// **'{successes} / {eligible} opportunities'**
  String statisticsSample(int successes, int eligible);

  /// No description provided for @statisticsResultsGraph.
  ///
  /// In en, this message translates to:
  /// **'Cumulative results'**
  String get statisticsResultsGraph;

  /// No description provided for @statisticsGraphDescription.
  ///
  /// In en, this message translates to:
  /// **'Chronological results for the selected player and filters. Large reports are sampled to 500 points, including the final result.'**
  String get statisticsGraphDescription;

  /// No description provided for @statisticsShowCurrency.
  ///
  /// In en, this message translates to:
  /// **'Show {currency}'**
  String statisticsShowCurrency(String currency);

  /// No description provided for @statisticsShowBigBlinds.
  ///
  /// In en, this message translates to:
  /// **'Show big blinds'**
  String get statisticsShowBigBlinds;

  /// No description provided for @statisticsNoGraph.
  ///
  /// In en, this message translates to:
  /// **'No result points match these filters.'**
  String get statisticsNoGraph;

  /// No description provided for @statisticsCurrencyGraphLabel.
  ///
  /// In en, this message translates to:
  /// **'Cumulative net result in {currency}'**
  String statisticsCurrencyGraphLabel(String currency);

  /// No description provided for @statisticsBigBlindsGraphLabel.
  ///
  /// In en, this message translates to:
  /// **'Cumulative net result in big blinds'**
  String get statisticsBigBlindsGraphLabel;

  /// No description provided for @statisticsFinalCurrency.
  ///
  /// In en, this message translates to:
  /// **'Final result: {amount}'**
  String statisticsFinalCurrency(String amount);

  /// No description provided for @statisticsFinalBigBlinds.
  ///
  /// In en, this message translates to:
  /// **'Final result: {amount} BB'**
  String statisticsFinalBigBlinds(String amount);

  /// No description provided for @statisticsAllHeading.
  ///
  /// In en, this message translates to:
  /// **'All core statistics'**
  String get statisticsAllHeading;

  /// No description provided for @statisticsSampleExplanation.
  ///
  /// In en, this message translates to:
  /// **'Rates show successes over eligible opportunities. A dash means no evidence, not zero percent.'**
  String get statisticsSampleExplanation;

  /// No description provided for @statisticsSmallSample.
  ///
  /// In en, this message translates to:
  /// **'Small sample'**
  String get statisticsSmallSample;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'About this copy of OpenRiver.'**
  String get settingsDescription;

  /// No description provided for @aboutHeading.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutHeading;

  /// No description provided for @coreVersion.
  ///
  /// In en, this message translates to:
  /// **'Core version {version}'**
  String coreVersion(String version);

  /// No description provided for @schemaVersion.
  ///
  /// In en, this message translates to:
  /// **'Library schema {version}'**
  String schemaVersion(int version);

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your hands stay on this device. OpenRiver needs no account or network connection.'**
  String get privacyNote;

  /// No description provided for @exportHeading.
  ///
  /// In en, this message translates to:
  /// **'Data export'**
  String get exportHeading;

  /// No description provided for @exportDescription.
  ///
  /// In en, this message translates to:
  /// **'Save a consistent SQLite backup of your library, including hands, import reports, and provenance. Keep the file somewhere safe.'**
  String get exportDescription;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'Export library backup'**
  String get exportAction;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup exported with {count, plural, =1{1 hand} other{{count} hands}}.'**
  String exportSuccess(int count);

  /// No description provided for @exportDestinationExists.
  ///
  /// In en, this message translates to:
  /// **'That file already exists. Choose a new filename so nothing is overwritten.'**
  String get exportDestinationExists;

  /// No description provided for @exportInvalidPath.
  ///
  /// In en, this message translates to:
  /// **'The backup could not be saved there. Choose a different location.'**
  String get exportInvalidPath;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup could not be completed. Check available storage and try again.'**
  String get exportFailed;

  /// No description provided for @exportChooserFailed.
  ///
  /// In en, this message translates to:
  /// **'The save dialog could not open. Please try again.'**
  String get exportChooserFailed;

  /// No description provided for @replayTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand replay'**
  String get replayTitle;

  /// Debug-only button on the Hands page that opens a built-in replay.
  ///
  /// In en, this message translates to:
  /// **'Open sample replay'**
  String get replaySampleAction;

  /// No description provided for @replayClose.
  ///
  /// In en, this message translates to:
  /// **'Close replay'**
  String get replayClose;

  /// An amount expressed in big blinds, e.g. 7.5 BB.
  ///
  /// In en, this message translates to:
  /// **'{value} BB'**
  String amountInBigBlinds(String value);

  /// No description provided for @streetPreflop.
  ///
  /// In en, this message translates to:
  /// **'Preflop'**
  String get streetPreflop;

  /// No description provided for @streetFlop.
  ///
  /// In en, this message translates to:
  /// **'Flop'**
  String get streetFlop;

  /// No description provided for @streetTurn.
  ///
  /// In en, this message translates to:
  /// **'Turn'**
  String get streetTurn;

  /// No description provided for @streetRiver.
  ///
  /// In en, this message translates to:
  /// **'River'**
  String get streetRiver;

  /// No description provided for @streetShowdown.
  ///
  /// In en, this message translates to:
  /// **'Showdown'**
  String get streetShowdown;

  /// No description provided for @positionSmallBlindShort.
  ///
  /// In en, this message translates to:
  /// **'SB'**
  String get positionSmallBlindShort;

  /// No description provided for @positionBigBlindShort.
  ///
  /// In en, this message translates to:
  /// **'BB'**
  String get positionBigBlindShort;

  /// No description provided for @positionUtgShort.
  ///
  /// In en, this message translates to:
  /// **'UTG'**
  String get positionUtgShort;

  /// No description provided for @positionUtg1Short.
  ///
  /// In en, this message translates to:
  /// **'UTG+1'**
  String get positionUtg1Short;

  /// No description provided for @positionUtg2Short.
  ///
  /// In en, this message translates to:
  /// **'UTG+2'**
  String get positionUtg2Short;

  /// No description provided for @positionUtg3Short.
  ///
  /// In en, this message translates to:
  /// **'UTG+3'**
  String get positionUtg3Short;

  /// No description provided for @positionLojackShort.
  ///
  /// In en, this message translates to:
  /// **'LJ'**
  String get positionLojackShort;

  /// No description provided for @positionHijackShort.
  ///
  /// In en, this message translates to:
  /// **'HJ'**
  String get positionHijackShort;

  /// No description provided for @positionCutoffShort.
  ///
  /// In en, this message translates to:
  /// **'CO'**
  String get positionCutoffShort;

  /// No description provided for @positionButtonShort.
  ///
  /// In en, this message translates to:
  /// **'BTN'**
  String get positionButtonShort;

  /// No description provided for @positionSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'small blind'**
  String get positionSmallBlind;

  /// No description provided for @positionBigBlind.
  ///
  /// In en, this message translates to:
  /// **'big blind'**
  String get positionBigBlind;

  /// No description provided for @positionUtg.
  ///
  /// In en, this message translates to:
  /// **'under the gun'**
  String get positionUtg;

  /// No description provided for @positionUtg1.
  ///
  /// In en, this message translates to:
  /// **'under the gun plus one'**
  String get positionUtg1;

  /// No description provided for @positionUtg2.
  ///
  /// In en, this message translates to:
  /// **'under the gun plus two'**
  String get positionUtg2;

  /// No description provided for @positionUtg3.
  ///
  /// In en, this message translates to:
  /// **'under the gun plus three'**
  String get positionUtg3;

  /// No description provided for @positionLojack.
  ///
  /// In en, this message translates to:
  /// **'lojack'**
  String get positionLojack;

  /// No description provided for @positionHijack.
  ///
  /// In en, this message translates to:
  /// **'hijack'**
  String get positionHijack;

  /// No description provided for @positionCutoff.
  ///
  /// In en, this message translates to:
  /// **'cutoff'**
  String get positionCutoff;

  /// No description provided for @positionButton.
  ///
  /// In en, this message translates to:
  /// **'button'**
  String get positionButton;

  /// No description provided for @actionSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'SB {amount}'**
  String actionSmallBlind(String amount);

  /// No description provided for @actionBigBlind.
  ///
  /// In en, this message translates to:
  /// **'BB {amount}'**
  String actionBigBlind(String amount);

  /// No description provided for @actionAnte.
  ///
  /// In en, this message translates to:
  /// **'Ante {amount}'**
  String actionAnte(String amount);

  /// No description provided for @actionFold.
  ///
  /// In en, this message translates to:
  /// **'Fold'**
  String get actionFold;

  /// No description provided for @actionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get actionCheck;

  /// No description provided for @actionCall.
  ///
  /// In en, this message translates to:
  /// **'Call {amount}'**
  String actionCall(String amount);

  /// No description provided for @actionBet.
  ///
  /// In en, this message translates to:
  /// **'Bet {amount}'**
  String actionBet(String amount);

  /// No description provided for @actionRaiseTo.
  ///
  /// In en, this message translates to:
  /// **'Raise to {amount}'**
  String actionRaiseTo(String amount);

  /// No description provided for @actionReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned {amount}'**
  String actionReturned(String amount);

  /// No description provided for @allIn.
  ///
  /// In en, this message translates to:
  /// **'All-in'**
  String get allIn;

  /// No description provided for @eventStart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 player seated} other{{count} players seated}}, blinds {smallBlind}/{bigBlind}'**
  String eventStart(int count, String smallBlind, String bigBlind);

  /// No description provided for @eventSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'{name} posts small blind {amount}'**
  String eventSmallBlind(String name, String amount);

  /// No description provided for @eventBigBlind.
  ///
  /// In en, this message translates to:
  /// **'{name} posts big blind {amount}'**
  String eventBigBlind(String name, String amount);

  /// No description provided for @eventAnte.
  ///
  /// In en, this message translates to:
  /// **'{name} posts ante {amount}'**
  String eventAnte(String name, String amount);

  /// No description provided for @eventFold.
  ///
  /// In en, this message translates to:
  /// **'{name} folds'**
  String eventFold(String name);

  /// No description provided for @eventCheck.
  ///
  /// In en, this message translates to:
  /// **'{name} checks'**
  String eventCheck(String name);

  /// No description provided for @eventCall.
  ///
  /// In en, this message translates to:
  /// **'{name} calls {amount}'**
  String eventCall(String name, String amount);

  /// No description provided for @eventBet.
  ///
  /// In en, this message translates to:
  /// **'{name} bets {amount}'**
  String eventBet(String name, String amount);

  /// No description provided for @eventRaiseTo.
  ///
  /// In en, this message translates to:
  /// **'{name} raises to {amount}'**
  String eventRaiseTo(String name, String amount);

  /// No description provided for @eventReturned.
  ///
  /// In en, this message translates to:
  /// **'{name} takes back {amount} uncalled'**
  String eventReturned(String name, String amount);

  /// Appended when an action puts the player all-in.
  ///
  /// In en, this message translates to:
  /// **'{action}, all-in'**
  String eventAllIn(String action);

  /// No description provided for @eventStreet.
  ///
  /// In en, this message translates to:
  /// **'{street}: {cards}'**
  String eventStreet(String street, String cards);

  /// No description provided for @eventStreetNoCards.
  ///
  /// In en, this message translates to:
  /// **'{street} begins'**
  String eventStreetNoCards(String street);

  /// No description provided for @eventShowdown.
  ///
  /// In en, this message translates to:
  /// **'Showdown'**
  String get eventShowdown;

  /// No description provided for @eventAward.
  ///
  /// In en, this message translates to:
  /// **'{name} wins {amount} from the {pot}'**
  String eventAward(String name, String amount, String pot);

  /// No description provided for @potMain.
  ///
  /// In en, this message translates to:
  /// **'main pot'**
  String get potMain;

  /// No description provided for @potSide.
  ///
  /// In en, this message translates to:
  /// **'side pot {index}'**
  String potSide(int index);

  /// No description provided for @potMainShort.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get potMainShort;

  /// No description provided for @potSideShort.
  ///
  /// In en, this message translates to:
  /// **'Side {index}'**
  String potSideShort(int index);

  /// No description provided for @potTotal.
  ///
  /// In en, this message translates to:
  /// **'Pot {amount}'**
  String potTotal(String amount);

  /// Pot including bets still in front of players.
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String potWithBets(String amount);

  /// No description provided for @seatFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}'**
  String seatFallbackName(int seat);

  /// No description provided for @seatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}, empty'**
  String seatEmpty(int seat);

  /// No description provided for @seatSummary.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}, {name}'**
  String seatSummary(int seat, String name);

  /// No description provided for @seatStack.
  ///
  /// In en, this message translates to:
  /// **'stack {amount}'**
  String seatStack(String amount);

  /// No description provided for @seatBet.
  ///
  /// In en, this message translates to:
  /// **'bet {amount}'**
  String seatBet(String amount);

  /// No description provided for @seatWon.
  ///
  /// In en, this message translates to:
  /// **'won {amount}'**
  String seatWon(String amount);

  /// No description provided for @seatFolded.
  ///
  /// In en, this message translates to:
  /// **'folded'**
  String get seatFolded;

  /// No description provided for @seatAllIn.
  ///
  /// In en, this message translates to:
  /// **'all-in'**
  String get seatAllIn;

  /// No description provided for @seatToAct.
  ///
  /// In en, this message translates to:
  /// **'to act'**
  String get seatToAct;

  /// No description provided for @seatDealer.
  ///
  /// In en, this message translates to:
  /// **'dealer button'**
  String get seatDealer;

  /// No description provided for @seatHolding.
  ///
  /// In en, this message translates to:
  /// **'holding {cards}'**
  String seatHolding(String cards);

  /// No description provided for @wonBadge.
  ///
  /// In en, this message translates to:
  /// **'Won {amount}'**
  String wonBadge(String amount);

  /// Single-letter dealer button marker on the table.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get dealerButton;

  /// No description provided for @rankJack.
  ///
  /// In en, this message translates to:
  /// **'jack'**
  String get rankJack;

  /// No description provided for @rankQueen.
  ///
  /// In en, this message translates to:
  /// **'queen'**
  String get rankQueen;

  /// No description provided for @rankKing.
  ///
  /// In en, this message translates to:
  /// **'king'**
  String get rankKing;

  /// No description provided for @rankAce.
  ///
  /// In en, this message translates to:
  /// **'ace'**
  String get rankAce;

  /// No description provided for @cardClubs.
  ///
  /// In en, this message translates to:
  /// **'{rank} of clubs'**
  String cardClubs(String rank);

  /// No description provided for @cardDiamonds.
  ///
  /// In en, this message translates to:
  /// **'{rank} of diamonds'**
  String cardDiamonds(String rank);

  /// No description provided for @cardHearts.
  ///
  /// In en, this message translates to:
  /// **'{rank} of hearts'**
  String cardHearts(String rank);

  /// No description provided for @cardSpades.
  ///
  /// In en, this message translates to:
  /// **'{rank} of spades'**
  String cardSpades(String rank);

  /// No description provided for @cardFaceDown.
  ///
  /// In en, this message translates to:
  /// **'face-down card'**
  String get cardFaceDown;

  /// No description provided for @replayFirst.
  ///
  /// In en, this message translates to:
  /// **'First step'**
  String get replayFirst;

  /// No description provided for @replayPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous step'**
  String get replayPrevious;

  /// No description provided for @replayPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get replayPlay;

  /// No description provided for @replayPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get replayPause;

  /// No description provided for @replayNext.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get replayNext;

  /// No description provided for @replayLast.
  ///
  /// In en, this message translates to:
  /// **'Last step'**
  String get replayLast;

  /// No description provided for @replayStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {count}'**
  String replayStepOf(int step, int count);

  /// No description provided for @replayScrubber.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get replayScrubber;

  /// No description provided for @replaySpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get replaySpeed;

  /// No description provided for @replaySpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{speed}×'**
  String replaySpeedValue(String speed);

  /// No description provided for @replayAmountsInBigBlinds.
  ///
  /// In en, this message translates to:
  /// **'Amounts in big blinds'**
  String get replayAmountsInBigBlinds;

  /// No description provided for @replayHideOpponentCards.
  ///
  /// In en, this message translates to:
  /// **'Hide opponents’ cards until showdown'**
  String get replayHideOpponentCards;

  /// No description provided for @replayActionLog.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get replayActionLog;

  /// No description provided for @replayShowActionLog.
  ///
  /// In en, this message translates to:
  /// **'Show actions'**
  String get replayShowActionLog;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
