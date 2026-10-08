import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const DriftRacerApp());

class DriftRacerApp extends StatelessWidget {
  const DriftRacerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.zenStone,
      title: 'Drift Racer',
      tagline: 'Drift through corners and own the leaderboard',
      emoji: '🏎️',
      slug: 'driftracer',
      howToPlay:
          '• 3 laps against 3 rival racers. Highest score wins!\n• Drag left/right to steer. HOLD the 💨 button to drift.\n• Drifting builds charge — release for a boost!\n• Chain drifts for multipliers. Stay off the grass!',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => DriftRacerScreen(players: players, callbacks: cb),
    );
  }
}
