import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Drift Racer: 3-lap drift battle vs 3 bots. Drag to steer, hold to drift.
class DriftRacerScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const DriftRacerScreen({super.key, required this.players, required this.callbacks});

  @override
  State<DriftRacerScreen> createState() => _DriftRacerScreenState();
}

class _Racer {
  final Player player;
  final bool human;
  double angle = 0; // total radians travelled
  double lateral = 0; // -1..1 across track
  double omega = 0;
  double charge = 0;
  bool drifting = false;
  double driftScore = 0;
  double chain = 0;
  double boost = 0;
  double wobble = 0;
  bool finished = false;
  double finishTime = 0;
  _Racer(this.player, this.human);
}

class _DriftRacerScreenState extends State<DriftRacerScreen> {
  static const laps = 3;
  static const lapRad = pi * 2;
  final _rand = Random();

  Ticker? _ticker;
  double _lastT = 0;
  List<_Racer> racers = [];
  List<Player> humans = [];
  int driverIdx = 0;
  bool racing = false;
  bool over = false;
  double raceTime = 0;
  bool holdDrift = false;
  double steerTarget = 0;
  Map<Player, double> finalScores = {};
  Map<Player, double> finalTimes = {};
  int countdown = 0;

  _Racer get me => racers.firstWhere((r) => r.human && r.player == humans[driverIdx]);

  @override
  void initState() {
    super.initState();
    humans = widget.players.where((p) => !p.isBot).toList();
    if (humans.isEmpty) humans = [widget.players.first];
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _startRace() {
    Sfx.click();
    driverIdx = 0;
    finalScores = {};
    finalTimes = {};
    _setupRun();
  }

  void _setupRun() {
    racers = [];
    final driver = humans[driverIdx];
    racers.add(_Racer(driver, true));
    // fill the grid to 4 cars with bots
    int bi = 0;
    for (final p in widget.players) {
      if (p == driver || racers.length >= 4) continue;
      racers.add(_Racer(p, false));
      bi++;
    }
    while (racers.length < 4) {
      racers.add(_Racer(PlayerPresets.make(20 + bi, isBot: true), false));
      bi++;
    }
    // staggered grid
    for (var i = 0; i < racers.length; i++) {
      racers[i].angle = -i * 0.35;
      racers[i].lateral = (i % 2 == 0 ? -0.4 : 0.4);
      racers[i].wobble = _rand.nextDouble() * 10;
    }
    raceTime = 0;
    holdDrift = false;
    steerTarget = 0;
    countdown = 3;
    racing = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 600), _countStep);
  }

  void _countStep() {
    if (!mounted || !racing) return;
    setState(() => countdown--);
    Sfx.tap();
    if (countdown > 0) {
      Future.delayed(const Duration(milliseconds: 600), _countStep);
    } else {
      Sfx.move();
      _lastT = 0;
      _ticker?.dispose();
      _ticker = Ticker(_tick)..start();
    }
  }

  void _tick(Duration d) {
    final t = d.inMicroseconds / 1e6;
    final dt = _lastT == 0 ? 0.016 : min(0.05, t - _lastT);
    _lastT = t;
    if (!mounted || !racing || over) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      raceTime += dt;
      const base = 1.15;
      for (final r in racers) {
        if (r.finished) continue;
        if (r.human) {
          _driveHuman(r, dt, base);
        } else {
          _driveBot(r, dt, base);
        }
        r.angle += r.omega * dt;
        if (r.angle >= laps * lapRad) {
          r.finished = true;
          r.finishTime = raceTime;
        }
      }
      if (me.finished) _endRun();
    });
  }

  void _driveHuman(_Racer r, double dt, double base) {
    r.lateral += (steerTarget - r.lateral) * min(1, dt * 6);
    final onGrass = r.lateral.abs() > 0.8;
    r.drifting = holdDrift && !onGrass;
    double target = base;
    if (r.drifting) {
      target = base * 1.5;
      r.charge = min(2.5, r.charge + dt);
      r.chain = min(4.0, r.chain + dt * 0.8);
      r.driftScore += 100 * (1 + r.chain * 0.5) * dt;
      r.lateral += r.lateral.sign * dt * 0.55; // slide out
      r.lateral = r.lateral.clamp(-1.2, 1.2);
    } else {
      if (r.charge > 0.25 && r.boost <= 0) {
        r.boost = r.charge * 0.9; // release = boost!
        Sfx.move();
      }
      r.charge = 0;
      r.chain = max(0, r.chain - dt * 1.5);
    }
    if (r.boost > 0) {
      r.boost -= dt;
      target = base * 1.9;
    }
    if (onGrass) target *= 0.55;
    r.omega += (target - r.omega) * min(1, dt * 4);
  }

  void _driveBot(_Racer r, double dt, double base) {
    // rubber-band a touch toward the human
    final gap = me.angle - r.angle;
    var pace = base * (0.94 + 0.05 * sin(raceTime * 0.7 + r.wobble));
    if (gap > pi) pace *= 1.06;
    if (gap < -pi) pace *= 0.94;
    r.omega += (pace - r.omega) * min(1, dt * 3);
    r.lateral = 0.35 * sin(raceTime * 1.3 + r.wobble);
    r.drifting = sin(raceTime * 0.9 + r.wobble) > 0.55;
  }

  int _positionOf(_Racer r) {
    final sorted = [...racers]..sort((a, b) => b.angle.compareTo(a.angle));
    return sorted.indexOf(r) + 1;
  }

  void _endRun() {
    _ticker?.stop();
    final driver = humans[driverIdx];
    // project bot finish times
    for (final r in racers) {
      if (!r.finished) r.finishTime = raceTime + (laps * lapRad - r.angle) / max(0.5, r.omega);
    }
    final order = [...racers]..sort((a, b) => a.finishTime.compareTo(b.finishTime));
    const bonus = [1000, 600, 300, 100];
    final myPlace = order.indexWhere((r) => r.player == driver) + 1;
    final score = me.driftScore + bonus[myPlace - 1];
    finalScores[driver] = score;
    finalTimes[driver] = me.finishTime;
    driver.score = score.round();
    widget.callbacks.refreshHud();
    if (myPlace == 1) {
      Sfx.win();
    } else {
      Sfx.lose();
    }
    if (driverIdx < humans.length - 1) {
      driverIdx++;
      widget.callbacks.setActivePlayer(driverIdx);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && !over) _setupRun();
      });
    } else {
      _finishMatch();
    }
    setState(() {});
  }

  void _finishMatch() {
    over = true;
    racing = false;
    final ranked = humans.toList()..sort((a, b) => finalScores[b]!.compareTo(finalScores[a]!));
    final winner = ranked.first;
    if (!winner.isBot) Sfx.win();
    final lines = ranked.map((p) => '${p.emoji} ${p.name}: ${finalScores[p]!.round()} pts (${finalTimes[p]!.toStringAsFixed(1)}s)').join('\n');
    widget.callbacks.finish(
      winner: winner,
      headline: '${winner.name} takes the checkered flag! 🏁',
      subline: lines,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        if (racing) _hud(theme),
        const SizedBox(height: 8),
        Expanded(
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              if (!racing || countdown > 0) return;
              setState(() => steerTarget = (steerTarget + d.delta.dx / 180).clamp(-1.0, 1.0));
            },
            child: _track(theme),
          ),
        ),
        const SizedBox(height: 8),
        if (!racing && !over)
          WajihaButton(
            label: humans.length > 1 ? 'Start race (P${driverIdx + 1} drives)' : 'Start race',
            emoji: '🏁',
            primary: true,
            onTap: _startRace,
          ),
        if (racing && countdown <= 0)
          GestureDetector(
            onTapDown: (_) => setState(() => holdDrift = true),
            onTapUp: (_) => setState(() => holdDrift = false),
            onTapCancel: () => setState(() => holdDrift = false),
            child: Container(
              width: 170,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: holdDrift ? theme.accent : theme.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: theme.accent, width: 3),
              ),
              child: Text('💨 DRIFT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: holdDrift ? Colors.white : theme.accent)),
            ),
          ),
        if (racing && countdown > 0)
          Text('Get ready…', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _hud(GameTheme t) {
    final r = racers.isEmpty ? null : me;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _cell(t, 'Lap', r == null ? '–' : '${(r.angle / lapRad).floor().clamp(0, laps) + 1}/$laps'),
          _cell(t, 'Pos', r == null ? '–' : _ord(_positionOf(r))),
          _cell(t, 'Drift', r == null ? '–' : '${r.driftScore.round()}'),
          _cell(t, 'Driver', humans[driverIdx].name.split(' ').first),
        ],
      ),
    );
  }

  String _ord(int n) => switch (n) { 1 => '1st 🥇', 2 => '2nd 🥈', 3 => '3rd 🥉', _ => '4th' };

  Widget _cell(GameTheme t, String label, String value) => Column(
        children: [
          Text(label, style: TextStyle(color: t.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(value, style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      );

  Widget _track(GameTheme t) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF2F6B2F), borderRadius: t.radius),
      child: LayoutBuilder(
        builder: (ctx, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final cx = w / 2;
          final cy = h / 2;
          final rr = min(w, h) * 0.30;
          return Stack(
            children: [
              CustomPaint(size: Size(w, h), painter: _TrackPainter(cx, cy, rr, t)),
              for (final r in racers) _carWidget(r, cx, cy, rr),
              if (countdown > 0)
                Center(
                  child: Text('$countdown', style: const TextStyle(fontSize: 90, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              if (racing && countdown <= 0 && me.drifting)
                const Positioned(top: 10, left: 0, right: 0, child: Center(child: Text('DRIFTING! 💨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)))),
            ],
          );
        },
      ),
    );
  }

  Widget _carWidget(_Racer r, double cx, double cy, double rr) {
    const trackW = 52.0;
    final a = -pi / 2 + (r.angle % lapRad);
    final rad = rr + r.lateral * trackW / 2;
    final x = cx + rad * cos(a);
    final y = cy + rad * 0.78 * sin(a);
    final heading = atan2(0.78 * cos(a), -sin(a)) + pi / 2;
    return Positioned(
      left: x - 14,
      top: y - 14,
      child: Transform.rotate(
        angle: heading + (r.drifting ? 0.45 * r.lateral.sign : 0),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: r.player.color,
            borderRadius: BorderRadius.circular(8),
            border: r.human && r.player == humans[driverIdx] ? Border.all(color: Colors.white, width: 3) : null,
          ),
          child: Text(r.human ? '🏎️' : '🚗', style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  final double cx, cy, rr;
  final GameTheme t;
  _TrackPainter(this.cx, this.cy, this.rr, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const trackW = 52.0;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: (rr + trackW / 2) * 2, height: (rr + trackW / 2) * 2 * 0.78);
    final paint = Paint()
      ..color = const Color(0xFF424242)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackW;
    canvas.drawOval(rect, paint);
    // grass inner
    final inner = Rect.fromCenter(center: Offset(cx, cy), width: (rr - trackW / 2) * 2, height: (rr - trackW / 2) * 2 * 0.78);
    canvas.drawOval(inner, Paint()..color = const Color(0xFF2F6B2F));
    // start line
    final sx = cx;
    final sy = cy - rr * 0.78;
    canvas.drawLine(
      Offset(sx - trackW / 2, sy),
      Offset(sx + trackW / 2, sy),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6,
    );
    // center island decor
    final text = TextPainter(
      text: const TextSpan(text: '🏁', style: TextStyle(fontSize: 40)),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(cx - 20, cy - 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
