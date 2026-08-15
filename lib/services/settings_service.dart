import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences, persisted with shared_preferences.
class SettingsService extends ChangeNotifier {
  static const _kDefaultFolder = 'default_folder';
  static const _kThemeMode = 'theme_mode';
  static const _kAccentSeed = 'accent_seed';
  static const _kConfirmOrganize = 'confirm_organize';
  static const _kConfirmDelete = 'confirm_delete';
  static const _kProtectSystemFolders = 'protect_system_folders';
  static const _kPreventOverwrite = 'prevent_overwrite';
  static const _kAutoScanOnStart = 'auto_scan_on_start';
  static const _kOnboardingDone = 'onboarding_done';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentSeed = const Color(0xFF6750A4); // Material 3 baseline purple
  String? _defaultFolder;
  bool _confirmOrganize = true;
  bool _confirmDelete = true;
  bool _protectSystemFolders = true;
  bool _preventOverwrite = true;
  bool _autoScanOnStart = false;
  bool _onboardingDone = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs!.getString(_kThemeMode),
      orElse: () => ThemeMode.system,
    );
    final seed = _prefs!.getInt(_kAccentSeed);
    if (seed != null) _accentSeed = Color(seed);
    _defaultFolder = _prefs!.getString(_kDefaultFolder);
    _confirmOrganize = _prefs!.getBool(_kConfirmOrganize) ?? true;
    _confirmDelete = _prefs!.getBool(_kConfirmDelete) ?? true;
    _protectSystemFolders =
        _prefs!.getBool(_kProtectSystemFolders) ?? true;
    _preventOverwrite = _prefs!.getBool(_kPreventOverwrite) ?? true;
    _autoScanOnStart = _prefs!.getBool(_kAutoScanOnStart) ?? false;
    _onboardingDone = _prefs!.getBool(_kOnboardingDone) ?? false;
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  Color get accentSeed => _accentSeed;
  String? get defaultFolder => _defaultFolder;
  bool get confirmOrganize => _confirmOrganize;
  bool get confirmDelete => _confirmDelete;
  bool get protectSystemFolders => _protectSystemFolders;
  bool get preventOverwrite => _preventOverwrite;
  bool get autoScanOnStart => _autoScanOnStart;
  bool get onboardingDone => _onboardingDone;

  set themeMode(ThemeMode value) {
    _themeMode = value;
    _prefs?.setString(_kThemeMode, value.name);
    notifyListeners();
  }

  set accentSeed(Color value) {
    _accentSeed = value;
    _prefs?.setInt(_kAccentSeed, value.toARGB32());
    notifyListeners();
  }

  set defaultFolder(String? value) {
    _defaultFolder = value;
    if (value == null) {
      _prefs?.remove(_kDefaultFolder);
    } else {
      _prefs?.setString(_kDefaultFolder, value);
    }
    notifyListeners();
  }

  set confirmOrganize(bool value) {
    _confirmOrganize = value;
    _prefs?.setBool(_kConfirmOrganize, value);
    notifyListeners();
  }

  set confirmDelete(bool value) {
    _confirmDelete = value;
    _prefs?.setBool(_kConfirmDelete, value);
    notifyListeners();
  }

  set protectSystemFolders(bool value) {
    _protectSystemFolders = value;
    _prefs?.setBool(_kProtectSystemFolders, value);
    notifyListeners();
  }

  set preventOverwrite(bool value) {
    _preventOverwrite = value;
    _prefs?.setBool(_kPreventOverwrite, value);
    notifyListeners();
  }

  set autoScanOnStart(bool value) {
    _autoScanOnStart = value;
    _prefs?.setBool(_kAutoScanOnStart, value);
    notifyListeners();
  }

  set onboardingDone(bool value) {
    _onboardingDone = value;
    _prefs?.setBool(_kOnboardingDone, value);
    notifyListeners();
  }

  /// Restores every preference to its default (used by "Reset settings").
  Future<void> resetAll() async {
    await _prefs?.clear();
    _themeMode = ThemeMode.system;
    _accentSeed = const Color(0xFF6750A4);
    _defaultFolder = null;
    _confirmOrganize = true;
    _confirmDelete = true;
    _protectSystemFolders = true;
    _preventOverwrite = true;
    _autoScanOnStart = false;
    _onboardingDone = false;
    notifyListeners();
  }
}
