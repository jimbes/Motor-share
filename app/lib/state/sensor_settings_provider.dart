import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the rider has opted into sensor capture (lean angle,
/// acceleration/braking, lateral G - REDL project doc, section 9.5).
/// Off by default: it's an explicit choice, not something enabled
/// automatically, so it never drains battery without consent.
class SensorSettingsProvider extends ChangeNotifier {
  static const _prefsKey = 'redl_sensors_enabled';

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_prefsKey);
    if (value != null) {
      _enabled = value;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}
