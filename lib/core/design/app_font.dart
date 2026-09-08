import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class AppFont {
  static const family = 'LXGW WenKai GB Screen';
  static const asset = 'assets/fonts/LXGWWenKaiGBScreen.ttf';
  static bool _registered = false;

  static void registerLicense() {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(const [
        family,
      ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    });
  }
}
