import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/race_themes.dart';

// ---------------------------------------------------------------------------
// Track geometry: superellipse center line with arc-length parameterization.
// World units: base radius R = 800. All physics runs in world units.
// ---------------------------------------------------------------------------
const double _trackR = 800.0;

class TrackGeom {
  final int styleIndex;
  late final double aspect = TrackStyles.aspect[styleIndex.clamp(0, 9)];
  late final double superExp = TrackStyles.superExp[styleIndex.clamp(0, 9)];
  late final double wobble = TrackStyles.wobble[styleIndex.clamp(0, 9)];
  late final double widthFrac = TrackStyles.width[styleIndex.clamp(0, 9)];

  static const int samples = 360;
  late final List<Offset> _centers;
  late final List<double> _cum;
  late final double lapLength;
  late final double halfWidth;

  TrackGeom(this.styleIndex) {
    _centers = List.generate(samples, (i) => _center(2 * pi * i / samples));
    _cum = List.filled(samples + 1, 0.0);
    for (int i = 1; i <= samples; i++) {
      final a = _centers[i - 1];
      final b = _centers[i % samples];
      _cum[i] = _cum[i - 1] + (b - a).distance;
    }
    lapLength = _cum[samples];
    halfWidth = widthFrac * _trackR;
  }

  double _sgnPow(double v, double e) => v.sign * pow(v.abs(), e).toDouble();

  Offset _center(double u) {
    final e = 2.0 / superExp;
    double x = _sgnPow(cos(u), e);
    double y = _sgnPow(sin(u), e) * aspect;
    x += wobble * sin(2 * u); // S-bend modulation
    return Offset(x * _trackR, y * _trackR);
  }

  double _uAt(double dist) {
    double d = dist % lapLength;
    if (d < 0) d += lapLength;
    int lo = 0, hi = samples;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cum[mid] < d) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final i = lo.clamp(1, samples);
    final c0 = _cum[i - 1], c1 = _cum[i];
    final f = c1 > c0 ? (d - c0) / (c1 - c0) : 0.0;
    return 2 * pi * ((i - 1 + f) / samples);
  }

  Offset centerAt(double dist) => _center(_uAt(dist));

  Offset tangentAt(double dist) {
    const du = 0.008;
    final u = _uAt(dist);
    final t = _center(u + du) - _center(u - du);
    final l = t.distance;
    return l > 1e-6 ? t / l : const Offset(1, 0);
  }

  Offset normalAt(double dist) {
    final t = tangentAt(dist);
    return Offset(-t.dy, t.dx);
  }

  /// |dHeading / dDist| — corner sharpness in rad per world unit.
  double curvatureAt(double dist) {
    const d = 3.0;
    final a = tangentAt(dist);
    final b = tangentAt(dist + d);
    final cross = a.dx * b.dy - a.dy * b.dx;
    final dot = (a.dx * b.dx + a.dy * b.dy).clamp(-1.0, 1.0);
    return (atan2(cross, dot).abs() / d);
  }

  /// 0 on straights … 1 in the tightest hairpins (tuned for R = 800).
  double cornerFactor(double dist) =>
      (curvatureAt(dist) * 1100.0).clamp(0.0, 1.0);

  /// World position of a racer given arc distance + lateral offset
  /// ([lat] in half-widths: 0 = center line, ±1 = track edge).
  Offset worldAt(double dist, double lat) {
    final c = centerAt(dist);
    final n = normalAt(dist);
    return c + n * (lat * halfWidth);
  }

  /// Bounding box of the full track band (for the painter's fit).
  Rect get bounds {
    double minX = 1e12, minY = 1e12, maxX = -1e12, maxY = -1e12;
    for (final c in _centers) {
      minX = min(minX, c.dx);
      minY = min(minY, c.dy);
      maxX = max(maxX, c.dx);
      maxY = max(maxY, c.dy);
    }
    const m = 1.35; // margin for half width + decorations
    return Rect.fromLTRB(minX * m, minY * m, maxX * m, maxY * m);
  }
}

// ---------------------------------------------------------------------------
// Race configuration / modes (RULES.md authoritative).
// ---------------------------------------------------------------------------
enum RaceMode { career, quick, timeTrial, endless }

enum BotDifficulty { easy, medium, hard }

/// Phases owned entirely by the engine. The UI only renders.
enum RacePhase { idle, countdown, racing, paused, finished }

class RaceConfig {
  final RaceMode mode;
  final int laps; // race modes
  final int botCount;
  final BotDifficulty difficulty;
  final int tier; // career tier index, -1 otherwise
  final double endlessSeconds;

  const RaceConfig({
    required this.mode,
    this.laps = 3,
    this.botCount = 2,
    this.difficulty = BotDifficulty.medium,
    this.tier = -1,
    this.endlessSeconds = 120,
  });

  bool get solo => botCount == 0;
}

/// UI hook for sounds / narration. Set by the screen.
enum RaceEvent {
  countdownTick,
  go,
  lapComplete,
  overtakeUp, // human gained a place
  overtakeDown, // a rival passed the human
  botDrift, // a rival started a visible drift
  driftChain, // human completed a chained drift
  boost,
  scrape, // human grinding the grass
  fenceHit, // human smacked the fence
  racerFinished,
  raceWon,
  raceLost,
  endlessDone,
  invalid,
}

// ---------------------------------------------------------------------------
// Racer state.
// ---------------------------------------------------------------------------
class Racer {
  String name;
  final Color color;
  final bool isBot;
  final double topSpeed;
  final double seed; // deterministic per-racer wobble

  double dist = 0;
  double lat = 0;
  double speed = 0;
  double steer = 0; // smoothed -1..1
  double steerTarget = 0;
  bool driftHeld = false; // input
  bool drifting = false;
  double charge = 0; // 0..1 boost charge while drifting
  double boostTime = 0;
  double chain = 0; // chained drift segments banked
  double chainGap = 0; // seconds since drift ended
  double driftScore = 0;
  double lapStart = 0;
  double bestLapMs = 0; // 0 = none yet
  double lastLapMs = 0;
  int lapsDone = 0;
  bool finished = false;
  double finishTime = 0;
  int place = 0;
  bool offTrack = false;
  double fenceCooldown = 0;
  double scrapeCooldown = 0;
  double visualAngle = 0; // extra yaw while drifting
  double think = 0; // AI decision timer
  final List<_TrailDot> trail = [];

  Racer({
    required this.name,
    required this.color,
    required this.isBot,
    required this.topSpeed,
    required this.seed,
  });

  /// Live ranking key: finished racers sort by finish time, the rest by
  /// distance. Lower is better.
  double get rankKey => finished ? -1e9 + finishTime : -dist;

  double get totalScore => driftScore;
}

class _TrailDot {
  Offset p;
  double age;
  _TrailDot(this.p, this.age);
}

// ---------------------------------------------------------------------------
// Engine: deterministic physics, AI, laps, scoring. UI-agnostic.
// ---------------------------------------------------------------------------
class RaceEngine extends ChangeNotifier {
  final RaceConfig config;
  final TrackGeom geom;
  final List<Racer> racers;

  RacePhase phase = RacePhase.idle;
  int countdownValue = 3;
  double raceTime = 0;
  String banner = '';
  bool over = false;

  /// Human touch input (screen writes these every frame).
  double humanSteer = 0;
  bool humanDrift = false;

  void Function(RaceEvent event, Racer? racer)? onEvent;

  Timer? _sim;
  Timer? _countdown;
  Timer? _watchdog;
  Timer? _bannerClear;
  DateTime _lastSimTick = DateTime.now();
  bool _disposed = false;
  bool paused = false;
  final _rand = Random(20261009);
  final List<int> _lastPlaces = [];
  double _botDriftNarrateCooldown = 0;

  static const double _tickHz = 60.0;

  RaceEngine({
    required this.config,
    required int trackStyle,
    required List<Racer> racers,
  })  : geom = TrackGeom(trackStyle),
        racers = racers {
    for (int i = 0; i < racers.length; i++) {
      _lastPlaces.add(i + 1);
      racers[i].place = i + 1;
    }
    // Staggered grid start: each racer a car-length behind the last.
    for (int i = 0; i < racers.length; i++) {
      racers[i].dist = -i * 55.0;
      racers[i].lat = (i % 2 == 0 ? -0.45 : 0.45);
    }
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
  }

  Racer get human => racers.firstWhere((r) => !r.isBot);
  int get humanIndex => racers.indexWhere((r) => !r.isBot);
  bool get racing => phase == RacePhase.racing && !paused;
  bool get countdown => phase == RacePhase.countdown;

  @override
  void dispose() {
    _disposed = true;
    _sim?.cancel();
    _countdown?.cancel();
    _watchdog?.cancel();
    _bannerClear?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ lifecycle
  void startRace() {
    if (_disposed || phase == RacePhase.countdown || racing) return;
    _resetRun();
    phase = RacePhase.countdown;
    countdownValue = 3;
    banner = 'Get ready…';
    notifyListeners();
    _armCountdown();
  }

  void _resetRun() {
    raceTime = 0;
    over = false;
    paused = false;
    humanSteer = 0;
    humanDrift = false;
    _botDriftNarrateCooldown = 0;
    for (int i = 0; i < racers.length; i++) {
      final r = racers[i];
      r.dist = -i * 55.0;
      r.lat = (i % 2 == 0 ? -0.45 : 0.45);
      r.speed = 0;
      r.steer = 0;
      r.steerTarget = 0;
      r.driftHeld = false;
      r.drifting = false;
      r.charge = 0;
      r.boostTime = 0;
      r.chain = 0;
      r.chainGap = 0;
      r.driftScore = 0;
      r.lapStart = 0;
      r.bestLapMs = 0;
      r.lastLapMs = 0;
      r.lapsDone = 0;
      r.finished = false;
      r.finishTime = 0;
      r.place = i + 1;
      r.offTrack = false;
      r.visualAngle = 0;
      r.trail.clear();
      _lastPlaces[i] = i + 1;
    }
    banner = '';
  }

  void restart() {
    _sim?.cancel();
    _sim = null;
    _countdown?.cancel();
    _countdown = null;
    phase = RacePhase.idle;
    startRace();
  }

  /// Pause: freeze the sim timer. Resume re-arms it. The watchdog never
  /// mistakes a pause for a stuck state.
  void setPaused(bool v) {
    if (_disposed || over) return;
    if (v == paused) return;
    paused = v;
    if (v) {
      _sim?.cancel();
      _sim = null;
      if (phase == RacePhase.racing) phase = RacePhase.paused;
    } else {
      if (phase == RacePhase.paused) phase = RacePhase.racing;
      _lastSimTick = DateTime.now();
      _startSim();
    }
    notifyListeners();
  }

  void _armCountdown() {
    if (_disposed || paused) return;
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed || paused) return;
      countdownValue--;
      if (countdownValue <= 0) {
        t.cancel();
        _countdown = null;
        phase = RacePhase.racing;
        banner = 'GO!';
        onEvent?.call(RaceEvent.go, null);
        _clearBannerSoon();
        _lastSimTick = DateTime.now();
        _startSim();
        notifyListeners();
      } else {
        banner = '$countdownValue';
        onEvent?.call(RaceEvent.countdownTick, null);
        notifyListeners();
      }
    });
  }

  void _startSim() {
    if (_disposed || paused || _sim != null) return;
    _lastSimTick = DateTime.now();
    _sim = Timer.periodic(
      Duration(microseconds: (1e6 / _tickHz).round()),
      (_) => _tick(1 / _tickHz),
    );
  }

  /// Watchdog: if the sim or countdown timer ever dies without progress,
  /// recover. Stuck states impossible by construction. Respects [paused].
  void _recover() {
    if (_disposed || over || paused) return;
    final silentMs =
        DateTime.now().difference(_lastSimTick).inMilliseconds;
    if (phase == RacePhase.racing && (silentMs > 500 || _sim == null)) {
      _sim?.cancel();
      _sim = null;
      _startSim();
    } else if (phase == RacePhase.countdown && _countdown == null) {
      _armCountdown();
    } else if (phase == RacePhase.paused && _sim != null) {
      _sim?.cancel();
      _sim = null;
    }
  }

  void _clearBannerSoon() {
    _bannerClear?.cancel();
    _bannerClear = Timer(const Duration(milliseconds: 1400), () {
      if (!_disposed) {
        banner = '';
        notifyListeners();
      }
    });
  }

  void say(String text) {
    banner = text;
    notifyListeners();
    _clearBannerSoon();
  }

  // ------------------------------------------------------------------ sim
  void _tick(double dt) {
    if (_disposed || paused || over) return;
    if (phase != RacePhase.racing) return;
    _lastSimTick = DateTime.now();
    raceTime += dt;
    _botDriftNarrateCooldown = max(0, _botDriftNarrateCooldown - dt);

    final diff = config.difficulty;
    for (final r in racers) {
      if (r.isBot && !r.finished) {
        _aiInput(r, diff, dt);
      } else if (!r.isBot && !r.finished) {
        r.steerTarget = humanSteer;
        r.driftHeld = humanDrift;
        r.steer += (r.steerTarget - r.steer) * min(1.0, dt * 10);
      }
      if (!r.finished) {
        _physics(r, dt);
      } else {
        // Finished racers cruise on for the visuals.
        r.speed += (r.topSpeed * 0.4 - r.speed) * min(1.0, dt * 2);
        r.dist += r.speed * dt;
      }
      // Age trail dots.
      for (final t in r.trail) {
        t.age += dt;
      }
      r.trail.removeWhere((t) => t.age > 1.6);
    }

    _updatePlaces();

    // Endless mode: time up ends the run.
    if (config.mode == RaceMode.endless &&
        raceTime >= config.endlessSeconds) {
      _finishRace();
      return;
    }
    // Race modes: human finished (plus a grace beat) or everyone finished.
    final h = human;
    if (!config.solo && h.finished && raceTime > h.finishTime + 2.0) {
      _finishRace();
      return;
    }
    if (racers.every((r) => r.finished)) {
      _finishRace();
      return;
    }
    // Absolute safety net: never run forever.
    if (raceTime > 900) _finishRace();
    notifyListeners();
  }

  void _physics(Racer r, double dt) {
    final ahead = r.dist + r.speed * 0.5;
    final corner = geom.cornerFactor(max(0.0, ahead));
    double target = r.topSpeed * (1 - 0.42 * corner);

    // --- drift state -------------------------------------------------
    final wantDrift = r.driftHeld &&
        r.steer.abs() > 0.22 &&
        r.speed > r.topSpeed * 0.42 &&
        !r.offTrack;
    if (wantDrift && !r.drifting) {
      r.drifting = true;
      if (r.isBot &&
          _botDriftNarrateCooldown <= 0 &&
          config.botCount > 0) {
        _botDriftNarrateCooldown = 6;
        say('${r.name} is drifting!');
        onEvent?.call(RaceEvent.botDrift, r);
      }
    }
    if (!wantDrift && r.drifting) {
      r.drifting = false;
      if (!r.isBot) {
        if (r.charge > 0.35 && r.boostTime <= 0) {
          r.boostTime = 0.8 + 1.6 * r.charge;
          onEvent?.call(RaceEvent.boost, r);
        } else if (r.charge > 0.12) {
          if (r.chainGap <= 1.4) {
            r.chain += 1;
          } else {
            r.chain = 1;
          }
          r.chainGap = 0;
          onEvent?.call(RaceEvent.driftChain, r);
        }
      }
      r.charge = 0;
    }
    if (r.drifting) {
      r.charge = min(1.0, r.charge + dt / 1.1);
      target = r.topSpeed * (1 - 0.20 * corner); // drifts carry corner speed
      final mult = 1 + 0.5 * min(r.chain, 6.0);
      r.driftScore += r.speed * dt * 0.9 * mult;
      r.visualAngle += (r.steer * 0.55 - r.visualAngle) * min(1.0, dt * 6);
      // Lay skid marks while drifting.
      if (_rand.nextDouble() < 0.85) {
        r.trail.add(_TrailDot(geom.worldAt(r.dist, r.lat), 0));
        if (r.trail.length > 60) r.trail.removeAt(0);
      }
    } else {
      r.visualAngle += (0 - r.visualAngle) * min(1.0, dt * 6);
      r.chainGap += dt;
      if (r.chainGap > 1.4) r.chain = 0;
    }

    // --- boost -------------------------------------------------------
    if (r.boostTime > 0) {
      r.boostTime -= dt;
      target = r.topSpeed * 1.38;
    }

    // --- accelerate toward target ------------------------------------
    final accel = target > r.speed ? r.topSpeed * 1.7 : r.topSpeed * 3.4;
    final dv = (target - r.speed).clamp(-accel * dt, accel * dt);
    r.speed = max(0.0, r.speed + dv);

    // --- lateral ------------------------------------------------------
    final latRate = 1.7 + (r.drifting ? 1.5 : 0.0); // half-widths per second
    r.lat += r.steer * latRate * dt * (0.55 + 0.45 * min(1.0, r.speed / r.topSpeed));
    // Grass drag + fence.
    r.fenceCooldown = max(0.0, r.fenceCooldown - dt);
    r.scrapeCooldown = max(0.0, r.scrapeCooldown - dt);
    final wasOff = r.offTrack;
    r.offTrack = r.lat.abs() > 1.0;
    if (r.offTrack) {
      r.speed = max(r.topSpeed * 0.30, r.speed - r.topSpeed * 2.2 * dt);
      if (!r.isBot) {
        r.chain = 0; // scraping the grass breaks the chain
        if (!wasOff || r.scrapeCooldown <= 0) {
          r.scrapeCooldown = 1.2;
          onEvent?.call(RaceEvent.scrape, r);
        }
      }
    }
    if (r.lat.abs() > 1.14) {
      r.lat = r.lat.sign * 1.14;
      if (r.fenceCooldown <= 0) {
        r.fenceCooldown = 0.9;
        r.speed *= 0.55;
        onEvent?.call(RaceEvent.fenceHit, r);
      }
    }

    // --- advance -------------------------------------------------------
    final prevLap = (r.dist / geom.lapLength).floor();
    r.dist += r.speed * dt;
    final newLap = (r.dist / geom.lapLength).floor();
    // newLap >= 1: the grid sits slightly behind the line, so the first
    // crossing (0) is the race start, not a completed lap.
    if (newLap > prevLap && newLap >= 1) {
      _onLap(r, newLap);
    }
  }

  void _onLap(Racer r, int newLap) {
    r.lapsDone = newLap;
    r.lastLapMs = (raceTime - r.lapStart) * 1000;
    r.lapStart = raceTime;
    if (r.bestLapMs == 0 || r.lastLapMs < r.bestLapMs) {
      r.bestLapMs = r.lastLapMs;
    }
    final target = config.mode == RaceMode.endless ? 1 << 30 : config.laps;
    if (!r.isBot) {
      onEvent?.call(RaceEvent.lapComplete, r);
      if (newLap >= target) {
        _finishRacer(r);
      } else {
        say(newLap == target - 1 ? 'Final lap!' : 'Lap ${newLap + 1}');
      }
    } else if (newLap >= target) {
      _finishRacer(r);
    }
  }

  void _finishRacer(Racer r) {
    r.finished = true;
    r.finishTime = raceTime;
    onEvent?.call(RaceEvent.racerFinished, r);
    _updatePlaces();
  }

  void _updatePlaces() {
    final order = [...racers]..sort((a, b) => a.rankKey.compareTo(b.rankKey));
    for (int i = 0; i < order.length; i++) {
      order[i].place = i + 1;
    }
    // Overtake narration for the human.
    final hi = humanIndex;
    if (hi >= 0) {
      final now = human.place;
      final was = _lastPlaces[hi];
      if (now < was && phase == RacePhase.racing) {
        say(now == 1 ? '${human.name} takes the lead!' : 'P$now — nice move!');
        onEvent?.call(RaceEvent.overtakeUp, human);
      } else if (now > was && phase == RacePhase.racing) {
        final passer = order.firstWhere(
          (r) => r.isBot && r.place == was,
          orElse: () => order.first,
        );
        if (passer.isBot) say('${passer.name} takes P$was!');
        onEvent?.call(RaceEvent.overtakeDown, passer.isBot ? passer : null);
      }
      _lastPlaces[hi] = now;
    }
  }

  // ------------------------------------------------------------------ AI
  static const _driftProb = [0.0, 0.55, 0.9];

  void _aiInput(Racer r, BotDifficulty diff, double dt) {
    r.think -= dt;
    if (r.think <= 0) {
      r.think = diff == BotDifficulty.easy ? 0.30 : 0.15;
      final d = diff.index;
      // Racing line: gentle weave, hugging the inside on corners.
      final ahead = r.dist + r.speed * 0.7;
      final corner = geom.cornerFactor(max(0.0, ahead));
      double targetLat = -0.30 * sin(r.dist * 0.004 + r.seed * 6.28);
      if (corner > 0.45) targetLat = targetLat * 0.3; // cut to the inside
      final gain = [1.1, 1.9, 2.7][d];
      double steer = ((targetLat - r.lat) * gain).clamp(-1.0, 1.0);
      // Lookahead: steer into the corner early.
      final aheadCorner = geom.cornerFactor(max(0.0, r.dist + r.speed * 1.1));
      if (aheadCorner > 0.5) {
        final side = sin(r.dist * 0.004 + r.seed * 6.28 + 1.2) >= 0 ? 1.0 : -1.0;
        steer = (steer + side * 0.35 * aheadCorner).clamp(-1.0, 1.0);
      }
      // Mistakes: easy bots wobble.
      if (d == 0 && _rand.nextDouble() < 0.18) {
        steer = (_rand.nextDouble() * 2 - 1) * 0.8;
      }
      // Visible drift behavior per difficulty (RULES: never silent auto-play
      // — bots visibly drift with smoke + narration).
      final wantDrift = corner > 0.42 &&
          r.speed > r.topSpeed * 0.72 &&
          _rand.nextDouble() < _driftProb[d];
      r.driftHeld = wantDrift;
      if (wantDrift && d == 2) steer = (steer * 1.35).clamp(-1.0, 1.0);
      r.steerTarget = steer;
    }
    r.steer += (r.steerTarget - r.steer) * min(1.0, dt * 7);
  }

  // --------------------------------------------------------------- results
  static const _positionPoints = [1000, 700, 500, 350];

  /// Final score breakdown for the results sheet.
  Map<Racer, RaceResult> results() {
    final order = [...racers]..sort((a, b) => a.rankKey.compareTo(b.rankKey));
    final out = <Racer, RaceResult>{};
    for (int i = 0; i < order.length; i++) {
      final r = order[i];
      final posPts = config.mode == RaceMode.endless
          ? 0
          : _positionPoints[min(i, _positionPoints.length - 1)];
      out[r] = RaceResult(
        place: i + 1,
        positionPoints: posPts,
        driftPoints: r.driftScore.round(),
        total: posPts + r.driftScore.round(),
        bestLapMs: r.bestLapMs,
        lapsDone: r.lapsDone,
      );
    }
    return out;
  }

  bool get humanWon =>
      over &&
      config.mode != RaceMode.endless &&
      human.place == 1;

  void _finishRace() {
    if (over) return;
    over = true;
    phase = RacePhase.finished;
    _sim?.cancel();
    _sim = null;
    _countdown?.cancel();
    _countdown = null;
    _updatePlaces();
    banner = '';
    notifyListeners();
    if (config.mode == RaceMode.endless) {
      onEvent?.call(RaceEvent.endlessDone, human);
    } else if (human.place == 1) {
      onEvent?.call(RaceEvent.raceWon, human);
    } else {
      onEvent?.call(RaceEvent.raceLost, human);
    }
  }
}

class RaceResult {
  final int place;
  final int positionPoints;
  final int driftPoints;
  final int total;
  final double bestLapMs;
  final int lapsDone;
  const RaceResult({
    required this.place,
    required this.positionPoints,
    required this.driftPoints,
    required this.total,
    required this.bestLapMs,
    required this.lapsDone,
  });
}

/// Bot top speeds per difficulty (human ≈ 262).
double botTopSpeed(BotDifficulty d) => switch (d) {
      BotDifficulty.easy => 214,
      BotDifficulty.medium => 250,
      BotDifficulty.hard => 278,
    };

const double humanTopSpeed = 262.0;
