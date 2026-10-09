import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pit_art.dart';
import '../theme/race_themes.dart';

/// Custom theme creator (PRO): paint every color role of the paddock.
/// Changes apply live and persist.
class CustomThemeScreen extends StatefulWidget {
  final DriftAudio audio;
  final RacerSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _palette = [
    0xFF2E2A1F, 0xFF4A4132, 0xFF1B1712, 0xFF3B2416, 0xFF5C3A21,
    0xFFF5EFE0, 0xFFD9CDAE, 0xFF222222, 0xFF5A5A5C, 0xFF3F3F41,
    0xFFC9A227, 0xFFE8CE7A, 0xFF8A6D1A, 0xFFD97941, 0xFFB0792F,
    0xFFC23B22, 0xFFA31621, 0xFF922B21, 0xFF2B6CB0, 0xFF1D4E9E,
    0xFF2F9E44, 0xFF1B7A4D, 0xFF4A7A2E, 0xFF3E7A34, 0xFF2F5D43,
    0xFFD9A62B, 0xFFF0C419, 0xFFE67E22, 0xFF7D3C98, 0xFF8E44AD,
    0xFF1A7A8C, 0xFF4E7A6B, 0xFFA8843F, 0xFF9A5A34, 0xFF6B8E23,
    0xFFB8BFC9, 0xFF767E8A, 0xFFDCE5EC, 0xFF8B95A1, 0xFFF4F6F8,
  ];

  Future<void> _pick(String key) async {
    final t = RaceThemes.byId(widget.settings.themeId,
        custom: widget.settings.customTheme);
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(CustomKeys.labels[key] ?? key,
                  style: Pit.display(20, theme: t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final c in _palette)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(c),
                            border: Border.all(
                              color: widget.settings.customColors[key] == c
                                  ? t.accentLight
                                  : Colors.black45,
                              width: widget.settings.customColors[key] == c
                                  ? 3
                                  : 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PitButton(
                label: 'Cancel',
                width: 150,
                fontSize: 15,
                theme: t,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      widget.audio.click();
      await widget.settings.setCustomColor(key, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaceThemes.byId('custom',
        custom: widget.settings.customTheme);
    final s = widget.settings;
    return PaddockBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Theme Creator',
              style: Pit.display(22, theme: t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: t.accentLight),
              tooltip: 'Reset colors',
              onPressed: () async {
                widget.audio.click();
                await s.resetCustomColors();
                setState(() {});
              },
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) {
            final live = RaceThemes.byId('custom',
                custom: s.customTheme);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // Live preview strip.
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: [
                        live.woodMid,
                        live.felt,
                      ]),
                      border: Border.all(
                          color: live.accent, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final c in live.playerColors)
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                  color: live.accentLight,
                                  width: 2),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(10),
                            color: live.accent,
                          ),
                          child: Text('Aa',
                              style: Pit.label(16,
                                  theme: live,
                                  color: live.woodDeep)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final key in CustomKeys.keys)
                    GestureDetector(
                      onTap: () => _pick(key),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(12),
                          color: live.woodDeep
                              .withValues(alpha: 0.65),
                          border: Border.all(
                              color: live.accent
                                  .withValues(alpha: 0.4),
                              width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(
                                    s.customColors[key] ??
                                        0xFF000000),
                                border: Border.all(
                                    color: live.accentLight,
                                    width: 2),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                CustomKeys.labels[key] ??
                                    key,
                                style: Pit.body(15,
                                    theme: live),
                              ),
                            ),
                            Icon(Icons.palette,
                                color: live.accentLight,
                                size: 20),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  PitButton(
                    label: 'Use My Creation',
                    width: 240,
                    theme: t,
                    onTap: () async {
                      widget.audio.click();
                      await s.setTheme('custom');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
