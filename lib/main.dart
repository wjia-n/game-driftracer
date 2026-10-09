import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/pit_art.dart';
import 'theme/race_themes.dart';

/// Drift Racer — toy-car drift racing. Landscape arcade racer:
/// drift through corners, chain drifts for multipliers, beat rival racers.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final settings = RacerSettings();
  await settings.load();
  final audio = DriftAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(DriftRacerApp(settings: settings, audio: audio));
}

class DriftRacerApp extends StatefulWidget {
  final RacerSettings settings;
  final DriftAudio audio;
  const DriftRacerApp(
      {super.key, required this.settings, required this.audio});

  @override
  State<DriftRacerApp> createState() => _DriftRacerAppState();
}

class _DriftRacerAppState extends State<DriftRacerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; the race screen additionally freezes its engine.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Drift Racer',
        debugShowCheckedModeBanner: false,
        theme: Pit.theme(RaceThemes.byId(widget.settings.themeId,
            custom: widget.settings.customTheme)),
        home: SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
