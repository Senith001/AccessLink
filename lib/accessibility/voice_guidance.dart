import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Serializes speech commands, keeping only the latest requested announcement.
class VoiceGuidance extends ChangeNotifier {
  VoiceGuidance({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setErrorHandler((_) => _reportError());
  }

  final FlutterTts _tts;
  bool _enabled = false;
  bool _configured = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _pending = Future.value();
  String? _error;
  String? get error => _error;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) unawaited(stop());
  }

  void _reportError([String? message]) {
    if (_disposed || !_enabled) return;
    _error =
        message ??
        'Voice guidance is unavailable. Check your device’s text-to-speech settings and try Test voice again.';
    notifyListeners();
  }

  Future<void> speak(String message) {
    if (!_enabled || _disposed || message.trim().isEmpty) return Future.value();
    final generation = ++_generation;
    return _pending = _pending.then((_) async {
      if (!_enabled || _disposed || generation != _generation) return;
      try {
        if (!_configured) {
          await _tts.awaitSpeakCompletion(false);
          final language = await _tts.setLanguage('en-US');
          if (language == 0) throw StateError('English voice unavailable');
          await _tts.setSpeechRate(0.45);
          await _tts.setVolume(1);
          _configured = true;
        }
        if (!_enabled || _disposed || generation != _generation) return;
        await _tts.stop();
        if (!_enabled || _disposed || generation != _generation) return;
        if (_error != null) {
          _error = null;
          notifyListeners();
        }
        final result = await _tts.speak(message);
        if (result == 0) throw StateError('Speech could not start');
      } on MissingPluginException {
        _configured = false;
        _reportError(
          'Voice guidance needs a full app update. Stop the app and run flutter run again; hot reload cannot install the speech service.',
        );
      } catch (error) {
        _configured = false;
        debugPrint('Voice guidance failed: $error');
        _reportError();
      }
    });
  }

  Future<void> stop() {
    ++_generation;
    return _pending = _pending.then((_) async {
      try {
        if (_configured) await _tts.stop();
      } catch (_) {
        // Stopping speech must never interrupt an app action.
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}

class VoiceGuidanceScope extends InheritedNotifier<VoiceGuidance> {
  const VoiceGuidanceScope({
    super.key,
    required VoiceGuidance voice,
    required super.child,
  }) : super(notifier: voice);

  static VoiceGuidance of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<VoiceGuidanceScope>()!
      .notifier!;

  static void announce(BuildContext context, String message) {
    final voice = context
        .getInheritedWidgetOfExactType<VoiceGuidanceScope>()
        ?.notifier;
    if (voice != null) unawaited(voice.speak(message));
  }
}