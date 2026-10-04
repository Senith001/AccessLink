import 'package:flutter/material.dart';

import '../accessibility/accessibility_settings.dart';
import '../accessibility/voice_guidance.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AccessibilityScope.of(context);
    final theme = Theme.of(context);
    final voice = VoiceGuidanceScope.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Voice assistance', style: theme.textTheme.headlineSmall),
            SwitchListTile(
              key: const ValueKey('voice-guidance-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Voice guidance'),
              subtitle: const Text(
                'Hear spoken feedback when you select buttons and controls.',
              ),
              value: settings.voiceGuidance,
              onChanged: (enabled) {
                settings.setVoiceGuidance(enabled);
                if (enabled) {
                  voice.speak(
                    'Voice guidance on. Tap a button to hear spoken feedback.',
                  );
                }
              },
            ),
            if (settings.voiceGuidance) ...[
              OutlinedButton.icon(
                onPressed: () => voice.speak(
                  'Voice guidance is ready. You can explore nearby places and choose your travel mode.',
                ),
                icon: const Icon(Icons.volume_up),
                label: const Text('Test voice'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Uses your device’s English voice and media volume. If you use TalkBack or VoiceOver, you can leave this off to avoid duplicate speech.',
              ),
              if (voice.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(liveRegion: true, child: Text(voice.error!)),
                ),
            ],
            const SizedBox(height: 24),
            Text('Reading & display', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              'Make AccessLink easier to read. Changes apply immediately.',
            ),
            const SizedBox(height: 24),
            Text('Text size', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Choose a comfortable size. Your phone’s text-size setting is also respected.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: TextSize.values
                  .map(
                    (size) => ChoiceChip(
                      label: Text(size.label),
                      selected: settings.textSize == size,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (selected) {
                        if (selected) {
                          settings.setTextSize(size);
                          voice.speak('${size.label} text selected');
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('High contrast'),
              subtitle: const Text(
                'Darker text, stronger controls, and solid backgrounds.',
              ),
              value: settings.highContrast,
              onChanged: (enabled) {
                settings.setHighContrast(enabled);
                voice.speak('High contrast ${enabled ? 'on' : 'off'}');
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outline, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Find nearby places and choose how you want to travel.',
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    Icons.directions,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (settings.saveError != null) ...[
              Text(settings.saveError!, semanticsLabel: settings.saveError),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: () {
                settings.reset();
                voice.speak('Display settings reset');
              },
              child: const Text(
                'Reset display settings',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}