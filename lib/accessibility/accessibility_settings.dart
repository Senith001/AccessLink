import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TextSize {
  standard('Standard', 1),
  large('Large', 1.3),
  extraLarge('Extra large', 1.6);

  const TextSize(this.label, this.scale);
  final String label;
  final double scale;
}

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings({SharedPreferences? preferences})
    : _preferences = preferences {
    try {
      final saved = preferences?.getString(_key);
      if (saved != null) {
        final values = jsonDecode(saved) as Map<String, dynamic>;
        _textSize = TextSize.values.byName(values['textSize'] as String);
        _highContrast = values['highContrast'] as bool;
        _voiceGuidance = values['voiceGuidance'] as bool? ?? false;
      }
    } catch (_) {
      _textSize = TextSize.standard;
      _highContrast = false;
    }
  }

  static const _key = 'accessibility_settings';
  final SharedPreferences? _preferences;
  TextSize _textSize = TextSize.standard;
  bool _highContrast = false;
  bool _voiceGuidance = false;
  String? _saveError;
  Future<void> _pendingSave = Future.value();

  TextSize get textSize => _textSize;
  bool get highContrast => _highContrast;
  bool get voiceGuidance => _voiceGuidance;
  String? get saveError => _saveError;

  Future<void> setTextSize(TextSize value) {
    _textSize = value;
    return _save();
  }

  Future<void> setHighContrast(bool value) {
    _highContrast = value;
    return _save();
  }

  Future<void> setVoiceGuidance(bool value) {
    _voiceGuidance = value;
    return _save();
  }

  Future<void> reset() {
    _textSize = TextSize.standard;
    _highContrast = false;
    return _save();
  }

  Future<void> _save() {
    final value = jsonEncode({
      'textSize': _textSize.name,
      'highContrast': _highContrast,
      'voiceGuidance': _voiceGuidance,
    });
    _saveError = null;
    notifyListeners();
    // Preserve the order of rapid changes so the last choice survives restart.
    return _pendingSave = _pendingSave.then((_) async {
      try {
        if (_preferences != null &&
            !await _preferences.setString(_key, value)) {
          throw StateError('Preferences were not saved');
        }
      } catch (_) {
        _saveError =
            'Your changes work now, but could not be saved. Please try again.';
        notifyListeners();
      }
    });
  }
}

class AccessibilityScope extends InheritedNotifier<AccessibilitySettings> {
  const AccessibilityScope({
    super.key,
    required AccessibilitySettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AccessibilitySettings of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AccessibilityScope>()!
      .notifier!;
}

/// Apply the app preference on top of the device's (possibly nonlinear) scaling.
class EnhancedTextScaler extends TextScaler {
  const EnhancedTextScaler(this.deviceScaler, this.factor);
  final TextScaler deviceScaler;
  final double factor;

  @override
  double scale(double fontSize) => deviceScaler.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is EnhancedTextScaler &&
      other.deviceScaler == deviceScaler &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(deviceScaler, factor);
}

ThemeData accessibilityTheme({bool highContrast = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF004B87),
    contrastLevel: highContrast ? 1 : 0,
    brightness: Brightness.light,
  );
  final colors = highContrast
      ? scheme.copyWith(
          primary: const Color(0xFF003366),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          onSurfaceVariant: Colors.black,
          outline: Colors.black,
        )
      : scheme;
  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    visualDensity: VisualDensity.standard,
  );
}