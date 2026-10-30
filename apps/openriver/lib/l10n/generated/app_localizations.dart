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
