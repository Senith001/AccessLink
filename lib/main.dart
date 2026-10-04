import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accessibility/accessibility_settings.dart';
import 'accessibility/voice_guidance.dart';
import 'screens/login_screen.dart';
import 'navigation/bottom_navigation.dart';
import 'navigation/home_screen.dart';

const String devScreen = String.fromEnvironment('DEV_SCREEN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }

  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // Display controls remain available for this session if storage fails.
  }
  
  // TEMPORARY DEV BYPASS: launch a screen directly via --dart-define=DEV_SCREEN=home. Remove before release. Default (no flag) keeps the normal auth/login flow.
  Widget? devBypassHome;
  if (devScreen == 'home') {
    devBypassHome = const BottomNavigationScreen();
  } else if (devScreen == 'home-tab') {
    devBypassHome = const HomeScreen();
  }
  
  runApp(
    AccessLinkApp(
      settings: AccessibilitySettings(preferences: preferences),
      home: devBypassHome,
    ),
  );
}

class AccessLinkApp extends StatefulWidget {
  const AccessLinkApp({super.key, this.settings, this.home});

  final AccessibilitySettings? settings;
  final Widget? home;

  @override
  State<AccessLinkApp> createState() => _AccessLinkAppState();
}

class _AccessLinkAppState extends State<AccessLinkApp>
    with WidgetsBindingObserver {
  late final AccessibilitySettings settings =
      widget.settings ?? AccessibilitySettings();

  late final VoiceGuidance voice = VoiceGuidance();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_syncVoice);
    _syncVoice();
  }

  void _syncVoice() => voice.setEnabled(settings.voiceGuidance);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncVoice();
    } else {
      voice.setEnabled(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    settings.removeListener(_syncVoice);
    voice.dispose();
    if (widget.settings == null) settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityScope(
      settings: settings,
      child: VoiceGuidanceScope(
        voice: voice,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'AccessLink',
            theme: accessibilityTheme(highContrast: settings.highContrast),
            highContrastTheme: accessibilityTheme(highContrast: true),
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: EnhancedTextScaler(
                    media.textScaler,
                    settings.textSize.scale,
                  ),
                  highContrast: media.highContrast || settings.highContrast,
                ),
                child: child!,
              );
            },
            home: widget.home ?? const LoginScreen(),
          ),
        ),
      ),
    );
  }
}