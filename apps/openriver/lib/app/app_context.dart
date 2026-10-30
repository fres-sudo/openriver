import 'package:openriver_ui/openriver_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// App members of `context.app`, alongside the UI kit's theme, responsive,
/// and input values.
extension AppContextMembers on RiverAppContext {
  /// Localized app strings, such as `context.app.localizations.navLibrary`.
  AppLocalizations get localizations => AppLocalizations.of(buildContext);
}
