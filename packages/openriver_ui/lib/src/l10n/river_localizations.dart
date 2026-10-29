import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// User-facing strings owned by the UI kit.
///
/// Apps register [delegate] and may supply translations by subclassing this
/// class and registering their own delegate ahead of it. Without a registered
/// delegate, [of] returns the English strings.
abstract class RiverLocalizations {
  const RiverLocalizations();

  static const LocalizationsDelegate<RiverLocalizations> delegate =
      _RiverLocalizationsDelegate();

  static RiverLocalizations of(BuildContext context) =>
      Localizations.of<RiverLocalizations>(context, RiverLocalizations) ??
      const RiverLocalizationsEn();

  /// Label of the main navigation region.
  String get navigationLabel;

  String get collapseSidebar;

  String get expandSidebar;

  String get close;

  /// Spoken description of a destination's badge, such as "3 new".
  String badgeCount(int count);
}

/// English kit strings, also the fallback for unsupported locales.
class RiverLocalizationsEn extends RiverLocalizations {
  const RiverLocalizationsEn();

  @override
  String get navigationLabel => 'Main navigation';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get close => 'Close';

  @override
  String badgeCount(int count) => count == 1 ? '1 new' : '$count new';
}

class _RiverLocalizationsDelegate
    extends LocalizationsDelegate<RiverLocalizations> {
  const _RiverLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<RiverLocalizations> load(Locale locale) =>
      SynchronousFuture(const RiverLocalizationsEn());

  @override
  bool shouldReload(_RiverLocalizationsDelegate old) => false;
}
