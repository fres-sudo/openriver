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
}
