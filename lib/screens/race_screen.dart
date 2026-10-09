import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/race_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/pit_art.dart';
import '../theme/race_themes.dart';

/// The race itself: pseudo-3D top-down toy-car track, touch steering,
/// hold-to-drift with boost release, visible AI rivals, drift chains,
/// lap scoring, pause, results, and hot-seat multiplayer.
class RaceScreen extends StatefulWidget {
  final DriftAudio audio;
  final RacerSettings settings;
  final RaceConfig config;
  final List<String> humanNames;
  final int tierIndex; // career tier, -1 otherwise

  const RaceScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.config,
    required this.humanNames,
    this.tierIndex = -1,
  });

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen>
    with WidgetsBindingObserver {
  late RaceEngine _engine;
  int _runIndex = 0; // hot-seat run number
  final List<_HotSeatRun> _runs = [];
  bool _showInterstitial = false; // "pass to next driver"
  bool _resultsShown = false;
  bool _dragging = false;
  double _dragAccum = 0;
  Timer? _loopSync;
  RaceThemeDef get _t => RaceThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);

  String get _driverName => widget.humanNames[_runIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = _makeEngine(_driverName);
    _loopSync = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      final e = _engine;
      if (e.racing && !e.paused) {
        if (e.human.drifting) {
          widget.audio.startScreechLoop();
        } else {
          widget.audio.startEngineLoop();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.audio.startGameMusic();
        _engine.startRace();
      }
    });
  }

  RaceEngine _makeEngine(String humanName) {
    final t = _t;
    final racers = <Racer>[
      Racer(
        name: humanName,
        color: t.playerColors[0],
        isBot: false,
        topSpeed: humanTopSpeed,
        seed: 0.13,
      ),
      for (int i = 0; i < widget.config.botCount; i++)
        Racer(
          name: widget.settings.driverNames[i + 1],
          color: t.playerColors[(i + 1) % t.playerColors.length],
          isBot: true,
          topSpeed: botTopSpeed(widget.config.difficulty),
          seed: 0.31 + i * 0.17,
        ),
    ];
    final e = RaceEngine(
      config: widget.config,
      trackStyle: widget.settings.trackStyle,
      racers: racers,
    );
    e.onEvent = _onEvent;
    return e;
  }

  void _onEvent(RaceEvent event, Racer? racer) {
    final a = widget.audio;
    switch (event) {
      case RaceEvent.countdownTick:
        a.countdownBeep();
      case RaceEvent.go:
        a.go();
        a.startEngineLoop();
      case RaceEvent.lapComplete:
        a.lap();
      case RaceEvent.overtakeUp:
        a.gameStart();
      case RaceEvent.overtakeDown:
        a.invalid();
      case RaceEvent.botDrift:
        break; // narration banner only
      case RaceEvent.driftChain:
        a.lap();
      case RaceEvent.boost:
        a.boost();
      case RaceEvent.scrape:
        a.invalid();
      case RaceEvent.fenceHit:
        a.crash();
      case RaceEvent.racerFinished:
        if (racer != null && !racer.isBot) a.lap();
      case RaceEvent.raceWon:
        a.stopLoop();
        a.win();
        a.startMenuMusic();
        _onRaceDone();
      case RaceEvent.raceLost:
        a.stopLoop();
        a.lose();
        a.startMenuMusic();
        _onRaceDone();
      case RaceEvent.endlessDone:
        a.stopLoop();
        a.record();
        a.startMenuMusic();
        _onRaceDone();
      case RaceEvent.invalid:
        a.invalid();
    }
  }

  Future<void> _onRaceDone() async {
    if (_resultsShown || !mounted) return;
    final s = widget.settings;
    final e = _engine;
    final res = e.results()[e.human]!;
    String? recordNote;
    int stars = 0;
    switch (widget.config.mode) {
      case RaceMode.career:
        final unlocked =
            await s.recordTierRace(tier: widget.tierIndex, place: res.place, humanWon: e.humanWon);
        stars = s.tierStars[widget.tierIndex];
        if (unlocked) recordNote = '🏆 Next tier unlocked!';
      case RaceMode.quick:
        // Hot-seat runs count as games but never as "wins" (no rivals).
        await s.recordQuickRace(
            won: e.humanWon && widget.humanNames.length == 1);
      case RaceMode.timeTrial:
        final rec = await s.recordTimeTrial(res.bestLapMs.round());
        if (rec) recordNote = '⚡ NEW LAP RECORD!';
      case RaceMode.endless:
        final rec = await s.recordEndless(res.total);
        if (rec) recordNote = '⚡ NEW SCORE RECORD!';
    }
    if (widget.humanNames.length > 1) {
      // Hot-seat: bank this run, move to the next driver.
      _runs.add(_HotSeatRun(
        name: _driverName,
        score: res.total,
        bestLapMs: res.bestLapMs,
        timeMs: e.raceTime * 1000,
      ));
      if (_runIndex + 1 < widget.humanNames.length) {
        setState(() {
          _resultsShown = false;
          _showInterstitial = true;
        });
        return;
      }
    }
    if (!mounted) return;
    if (recordNote != null || stars > 0) {
      _resultNote = recordNote;
      _resultStars = stars;
    }
    setState(() => _resultsShown = true);
    _maybeAskReview();
  }

  String? _resultNote;
  int _resultStars = 0;

  Future<void> _maybeAskReview() async {
    final s = widget.settings;
    if (s.reviewAsked || s.gamesPlayed < 3) return;
    await s.markReviewAsked();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {}
  }

  void _nextHotSeatRun() {
    setState(() {
      _runIndex++;
      _showInterstitial = false;
      _resultsShown = false;
      _resultNote = null;
      _resultStars = 0;
      _engine.dispose();
      _engine = _makeEngine(_driverName);
    });
    widget.audio.startGameMusic();
    _engine.startRace();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding mid-race auto-pauses the engine (audio is handled
    // by the app-level observer).
    if (state == AppLifecycleState.paused && _engine.racing) {
      _engine.setPaused(true);
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loopSync?.cancel();
    _engine.dispose();
    super.dispose();
  }

  void _quit() {
    widget.audio.click();
    widget.audio.stopLoop();
    widget.audio.startMenuMusic();
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------- controls
  void _onSteerDrag(DragUpdateDetails d) {
    _dragAccum += d.delta.dx;
    final v = (_dragAccum / 90).clamp(-1.0, 1.0);
    _engine.humanSteer = v;
  }

  void _endSteer() {
    _dragging = false;
    _dragAccum = 0;
    _engine.humanSteer = 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.felt,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _engine,
          builder: (context, _) {
            final e = _engine;
            return Stack(
              children: [
                // Track.
                Positioned.fill(
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      _dragging = true;
                      _dragAccum = 0;
                    },
                    onHorizontalDragUpdate: _onSteerDrag,
                    onHorizontalDragEnd: (_) => _endSteer(),
                    onHorizontalDragCancel: _endSteer,
                    child: CustomPaint(
                      painter: _RacePainter(
                        engine: e,
                        theme: t,
                        carStyle: widget.settings.carStyle,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
                // HUD.
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: _Hud(
                    theme: t,
                    engine: e,
                    config: widget.config,
                    onPause: () {
                      widget.audio.click();
                      widget.audio.onAppPaused();
                      e.setPaused(true);
                      setState(() {});
                    },
                  ),
                ),
                // Narration banner.
                if (e.banner.isNotEmpty)
                  Positioned(
                    top: 64,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.black.withValues(alpha: 0.55),
                          border: Border.all(
                              color: t.accent.withValues(alpha: 0.7)),
                        ),
                        child: Text(e.banner,
                            style: Pit.label(16, theme: t)),
                      ),
                    ),
                  ),
                // Countdown overlay.
                if (e.countdown)
                  Center(
                    child: Text(
                      e.countdownValue > 0 ? '${e.countdownValue}' : 'GO!',
                      style: Pit.display(110, theme: t),
                    ),
                  ),
                // Drift chain + charge, bottom-left.
                if (e.racing || e.phase == RacePhase.paused)
                  Positioned(
                    left: 14,
                    bottom: 16,
                    child: _DriftMeter(theme: t, engine: e),
                  ),
                // Drift button, bottom-right (icon-based, animated press).
                if (e.racing)
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: _DriftButton(
                      theme: t,
                      onDown: () {
                        e.humanDrift = true;
                      },
                      onUp: () {
                        e.humanDrift = false;
                      },
                    ),
                  ),
                // Steering hint.
                if (e.racing && !_dragging && e.raceTime < 6)
                  const Positioned(
                    bottom: 110,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        '◀ Drag to steer  •  HOLD the skid button to drift ▶',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                // Pause overlay.
                if (e.phase == RacePhase.paused && !_showInterstitial)
                  _PauseOverlay(
                    theme: t,
                    audio: widget.audio,
                    settings: widget.settings,
                    onResume: () {
                      widget.audio.click();
                      widget.audio.onAppResumed();
                      e.setPaused(false);
                      setState(() {});
                    },
                    onRestart: () {
                      widget.audio.click();
                      widget.audio.onAppResumed();
                      e.setPaused(false);
                      e.restart();
                      setState(() {});
                    },
                    onQuit: _quit,
                  ),
                // Hot-seat interstitial.
                if (_showInterstitial)
                  _Interstitial(
                    theme: t,
                    title: 'Pass the device!',
                    body:
                        '${widget.humanNames[_runIndex + 1]}, you\'re up.\n2 solo laps — fastest total time wins.',
                    cta: 'Start my run',
                    onTap: () {
                      widget.audio.click();
                      _nextHotSeatRun();
                    },
                  ),
                // Results.
                if (_resultsShown)
                  _ResultsSheet(
                    theme: t,
                    audio: widget.audio,
                    settings: widget.settings,
                    engine: e,
                    config: widget.config,
                    hotSeatRuns: widget.humanNames.length > 1
                        ? _runs
                        : const [],
                    note: _resultNote,
                    stars: _resultStars,
                    onAgain: () {
                      widget.audio.click();
                      setState(() {
                        _resultsShown = false;
                        _resultNote = null;
                        _resultStars = 0;
                        _runIndex = 0;
                        _runs.clear();
                        _engine.dispose();
                        _engine = _makeEngine(_driverName);
                      });
                      widget.audio.startGameMusic();
                      _engine.startRace();
                    },
                    onQuit: _quit,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HotSeatRun {
  final String name;
  final int score;
  final double bestLapMs;
  final double timeMs;
  const _HotSeatRun({
    required this.name,
    required this.score,
    required this.bestLapMs,
    required this.timeMs,
  });
}

// ---------------------------------------------------------------------------
/// Top HUD: lap / position / time / score / pause.
class _Hud extends StatelessWidget {
  final RaceThemeDef theme;
  final RaceEngine engine;
  final RaceConfig config;
  final VoidCallback onPause;
  const _Hud(
      {required this.theme,
      required this.engine,
      required this.config,
      required this.onPause});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final h = e.human;
    final lapText = config.mode == RaceMode.endless
        ? '${(config.endlessSeconds - e.raceTime).clamp(0, 999).toStringAsFixed(0)}s'
        : 'Lap ${min(h.lapsDone + 1, config.laps)}/${config.laps}';
    return Row(
      children: [
        _HudChip(theme: theme, text: lapText),
        const SizedBox(width: 8),
        if (config.mode != RaceMode.endless)
          _HudChip(
              theme: theme,
              text: 'P${h.place}/${e.racers.length}',
              hot: true),
        const Spacer(),
        _HudChip(theme: theme, text: _fmtTime(e.raceTime)),
        const SizedBox(width: 8),
        _HudChip(theme: theme, text: '${h.driftScore.round()} pts'),
        const SizedBox(width: 8),
        _IconCircle(
          theme: theme,
          icon: Icons.pause,
          onTap: e.racing ? onPause : () {},
        ),
      ],
    );
  }
}

String _fmtTime(double seconds) {
  final s = seconds.clamp(0, 5999);
  final m = (s / 60).floor();
  final sec = (s % 60).floor();
  final tenths = ((s * 10) % 10).floor();
  return '$m:${sec.toString().padLeft(2, '0')}.$tenths';
}

String _fmtLapMs(double ms) {
  if (ms <= 0) return '—';
  return _fmtTime(ms / 1000);
}

class _HudChip extends StatelessWidget {
  final RaceThemeDef theme;
  final String text;
  final bool hot;
  const _HudChip(
      {required this.theme, required this.text, this.hot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(
            color: hot
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.6),
            width: hot ? 2.5 : 1.5),
      ),
      child: Text(text, style: Pit.label(14, theme: theme)),
    );
  }
}

/// Small circular icon button with animated press feedback.
class _IconCircle extends StatefulWidget {
  final RaceThemeDef theme;
  final IconData icon;
  final VoidCallback onTap;
  const _IconCircle(
      {required this.theme,
      required this.icon,
      required this.onTap});

  @override
  State<_IconCircle> createState() => _IconCircleState();
}

class _IconCircleState extends State<_IconCircle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 44,
        height: 44,
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.accentLight, t.accent, t.accentDark],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: Offset(0, _pressed ? 2 : 5),
              blurRadius: _pressed ? 3 : 8,
            ),
          ],
        ),
        child: Icon(widget.icon, color: t.woodDeep, size: 44 * 0.52),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Drift chain meter + boost charge bar (bottom-left).
class _DriftMeter extends StatelessWidget {
  final RaceThemeDef theme;
  final RaceEngine engine;
  const _DriftMeter({required this.theme, required this.engine});

  @override
  Widget build(BuildContext context) {
    final h = engine.human;
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.55),
        border:
            Border.all(color: theme.accent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('💨', style: Pit.body(15, theme: theme)),
              const SizedBox(width: 6),
              Text(
                h.drifting
                    ? 'DRIFTING'
                    : h.chain > 0
                        ? 'CHAIN x${h.chain.round()}'
                        : 'DRIFT',
                style: Pit.label(13, theme: theme),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: h.drifting
                  ? h.charge.clamp(0.02, 1.0)
                  : (h.boostTime > 0 ? 1.0 : 0.02),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [
                    theme.accentLight,
                    theme.accent,
                  ]),
                ),
              ),
            ),
          ),
          if (h.boostTime > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('⚡ BOOST!',
                  style: Pit.label(12, theme: theme)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Big hold-to-drift button (icon-based, animated press).
class _DriftButton extends StatefulWidget {
  final RaceThemeDef theme;
  final VoidCallback onDown;
  final VoidCallback onUp;
  const _DriftButton(
      {required this.theme, required this.onDown, required this.onUp});

  @override
  State<_DriftButton> createState() => _DriftButtonState();
}

class _DriftButtonState extends State<_DriftButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onDown();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onUp();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        widget.onUp();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 92,
        height: 92,
        transform: Matrix4.diagonal3Values(
            _pressed ? 0.92 : 1.0, _pressed ? 0.92 : 1.0, 1.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _pressed
                ? [t.accent, t.accentDark]
                : [t.accentLight, t.accent, t.accentDark],
          ),
          border: Border.all(color: t.ivory, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(Icons.sports_motorsports,
            color: t.woodDeep, size: 44),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final RaceThemeDef theme;
  final DriftAudio audio;
  final RacerSettings settings;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay({
    required this.theme,
    required this.audio,
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Pit.display(30, theme: t)),
              const SizedBox(height: 16),
              PitButton(
                  label: 'Resume', onTap: onResume, theme: t, width: 240),
              const SizedBox(height: 10),
              PitButton(
                  label: 'Restart race',
                  onTap: onRestart,
                  theme: t,
                  width: 240),
              const SizedBox(height: 10),
              PitButton(
                  label: 'Quit to menu',
                  onTap: onQuit,
                  theme: t,
                  width: 240),
              const SizedBox(height: 14),
              SettingRow(
                theme: t,
                label: 'Music',
                control: PitToggle(
                  theme: t,
                  value: settings.musicOn,
                  onChanged: (v) async {
                    audio.click();
                    await settings.setMusic(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                    if (v) {
                      audio.startGameMusic();
                    } else {
                      audio.stopMusic();
                    }
                  },
                ),
              ),
              SettingRow(
                theme: t,
                label: 'Sound effects',
                control: PitToggle(
                  theme: t,
                  value: settings.sfxOn,
                  onChanged: (v) async {
                    await settings.setSfx(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                    if (v) audio.click();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Interstitial extends StatelessWidget {
  final RaceThemeDef theme;
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;
  const _Interstitial({
    required this.theme,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Pit.display(28, theme: t)),
              const SizedBox(height: 10),
              Text(body,
                  style: Pit.body(15, theme: t),
                  textAlign: TextAlign.center),
              const SizedBox(height: 18),
              PitButton(label: cta, onTap: onTap, theme: t, width: 240),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ResultsSheet extends StatelessWidget {
  final RaceThemeDef theme;
  final DriftAudio audio;
  final RacerSettings settings;
  final RaceEngine engine;
  final RaceConfig config;
  final List<_HotSeatRun> hotSeatRuns;
  final String? note;
  final int stars;
  final VoidCallback onAgain;
  final VoidCallback onQuit;
  const _ResultsSheet({
    required this.theme,
    required this.audio,
    required this.settings,
    required this.engine,
    required this.config,
    required this.hotSeatRuns,
    required this.note,
    required this.stars,
    required this.onAgain,
    required this.onQuit,
  });

  String get _title {
    if (config.mode == RaceMode.endless) return 'Time Up!';
    if (hotSeatRuns.length > 1) return 'Final Standings';
    return engine.humanWon ? '🏆 Victory!' : 'Race Over';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final results = engine.results();
    final order = results.keys.toList()
      ..sort((a, b) => a.rankKey.compareTo(b.rankKey));
    final hotSeat = hotSeatRuns.length > 1;
    final sortedRuns = hotSeat
        ? ([...hotSeatRuns]
          ..sort((a, b) => a.timeMs.compareTo(b.timeMs)))
        : hotSeatRuns;
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 520),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_title, style: Pit.display(32, theme: t)),
                if (stars > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('★' * stars + '☆' * (3 - stars),
                        style: TextStyle(
                            fontSize: 26, color: t.accentLight)),
                  ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(note!,
                        style: Pit.label(15, theme: t),
                        textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 12),
                if (hotSeat)
                  for (int i = 0; i < sortedRuns.length; i++)
                    _standingsRow(
                        t,
                        i + 1,
                        sortedRuns[i].name,
                        _fmtTime(sortedRuns[i].timeMs / 1000),
                        'Best lap ${_fmtLapMs(sortedRuns[i].bestLapMs)} • ${sortedRuns[i].score} pts')
                else
                  for (final r in order)
                    _standingsRow(
                      t,
                      results[r]!.place,
                      r.name + (r.isBot ? '' : '  (you)'),
                      '${results[r]!.total} pts',
                      config.mode == RaceMode.endless
                          ? 'Drift ${results[r]!.driftPoints}'
                          : 'Best lap ${_fmtLapMs(results[r]!.bestLapMs)}',
                    ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _IconCircle(
                        theme: t, icon: Icons.refresh, onTap: onAgain),
                    const SizedBox(width: 18),
                    _IconCircle(
                      theme: t,
                      icon: Icons.share,
                      onTap: () async {
                        audio.click();
                        final h = engine.human;
                        final res = results[h]!;
                        await SharePlus.instance.share(ShareParams(
                          text:
                              'I scored ${res.total} pts in Drift Racer! 🏁 Think you can out-drift me? https://play.google.com/store/apps/details?id=com.gameswajiha.driftracer',
                        ));
                      },
                    ),
                    const SizedBox(width: 18),
                    _IconCircle(
                      theme: t,
                      icon: Icons.star_rate,
                      onTap: () async {
                        audio.click();
                        try {
                          final review = InAppReview.instance;
                          if (await review.isAvailable()) {
                            await review.requestReview();
                          } else {
                            await review.openStoreListing(appStoreId: null);
                          }
                        } catch (_) {}
                      },
                    ),
                    const SizedBox(width: 18),
                    _IconCircle(
                        theme: t, icon: Icons.home, onTap: onQuit),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _standingsRow(
      RaceThemeDef t, int place, String name, String score, String sub) {
    const medals = ['🥇', '🥈', '🥉', '4️⃣'];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: place == 1
            ? t.accent.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.3),
        border: Border.all(
            color: place == 1
                ? t.accentLight
                : t.accent.withValues(alpha: 0.35),
            width: place == 1 ? 2.5 : 1.2),
      ),
      child: Row(
        children: [
          Text(medals[min(place - 1, 3)], style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Pit.label(15, theme: t)),
                Text(sub,
                    style: Pit.body(12,
                        theme: t,
                        color: t.ivory.withValues(alpha: 0.65))),
              ],
            ),
          ),
          Text(score, style: Pit.display(18, theme: t)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Track + car painter: pseudo-3D toy-car world, physical materials.
// ---------------------------------------------------------------------------
class _RacePainter extends CustomPainter {
  final RaceEngine engine;
  final RaceThemeDef theme;
  final int carStyle;

  _RacePainter({
    required this.engine,
    required this.theme,
    required this.carStyle,
  });

  Color _shade(Color c, double f) {
    int ch(double v) => (v * f).round().clamp(0, 255);
    return Color.fromARGB(
        (c.a * 255).round(), ch(c.r), ch(c.g), ch(c.b));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geom = engine.geom;
    final bounds = geom.bounds;
    final s =
        min(size.width / bounds.width, size.height / bounds.height);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(
        -(bounds.left + bounds.right) / 2, -(bounds.top + bounds.bottom) / 2);

    _paintGrass(canvas, bounds);
    _paintTrack(canvas, geom);
    _paintDecor(canvas, geom);
    _paintSkids(canvas);
    _paintCars(canvas, geom);

    canvas.restore();
  }

  void _paintGrass(Canvas canvas, Rect bounds) {
    canvas.drawRect(bounds, Paint()..color = theme.felt);
    // Mow stripes.
    canvas.save();
    canvas.clipRect(bounds);
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.045);
    for (double x = bounds.left - bounds.height;
        x < bounds.right + bounds.height;
        x += 170) {
      canvas.drawRect(Rect.fromLTWH(x, bounds.top, 85, bounds.height), stripe);
    }
    canvas.restore();
    // Soft vignette.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0),
          radius: 0.75,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
        ).createShader(bounds),
    );
  }

  List<Offset> _edge(TrackGeom geom, double lat, int n) {
    return List.generate(
        n, (i) => geom.worldAt(geom.lapLength * i / n, lat));
  }

  void _paintTrack(Canvas canvas, TrackGeom geom) {
    const n = 140;
    final outer = _edge(geom, 1.0, n);
    final inner = _edge(geom, -1.0, n);
    final path = Path()
      ..moveTo(outer[0].dx, outer[0].dy);
    for (final p in outer.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    for (int i = n - 1; i >= 0; i--) {
      path.lineTo(inner[i].dx, inner[i].dy);
    }
    path.close();
    // Asphalt with physical depth: dark base, lighter driving band.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.trackDark, theme.trackLight, theme.trackDark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(geom.bounds),
    );
    // Edge lines.
    final edgePaint = Paint()
      ..color = theme.ivory.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final outerPath = Path()..moveTo(outer[0].dx, outer[0].dy);
    for (final p in outer.skip(1)) {
      outerPath.lineTo(p.dx, p.dy);
    }
    outerPath.close();
    final innerPath = Path()..moveTo(inner[0].dx, inner[0].dy);
    for (final p in inner.skip(1)) {
      innerPath.lineTo(p.dx, p.dy);
    }
    innerPath.close();
    canvas.drawPath(outerPath, edgePaint);
    canvas.drawPath(innerPath, edgePaint);
    // Center dashes.
    final dashPaint = Paint()
      ..color = theme.ivory.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    for (int i = 0; i < n; i += 6) {
      final a = geom.worldAt(geom.lapLength * i / n, 0);
      final b = geom.worldAt(geom.lapLength * (i + 3) / n, 0);
      canvas.drawLine(a, b, dashPaint);
    }
    // Red/white curbs on the outer edge.
    for (int i = 0; i < n; i += 7) {
      final d = geom.lapLength * i / n;
      final p = geom.worldAt(d, 1.0);
      final t = geom.tangentAt(d);
      final ang = atan2(t.dy, t.dx);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(ang);
      canvas.drawRect(
        const Rect.fromLTWH(-26, -14, 52, 28),
        Paint()
          ..color = (i ~/ 7) % 2 == 0
              ? theme.playerColors[0]
              : theme.ivory,
      );
      canvas.restore();
    }
    // Checkered start/finish line.
    const rows = 2, cols = 8;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final lat = -1.0 + 2.0 * (c + 0.5) / cols;
        final p = geom.worldAt(r * 14.0, lat);
        final t = geom.tangentAt(0);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(atan2(t.dy, t.dx));
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: 15,
              height: 2 * geom.halfWidth / cols + 2),
          Paint()
            ..color = (r + c) % 2 == 0 ? Colors.black87 : theme.ivory,
        );
        canvas.restore();
      }
    }
  }

  void _paintDecor(Canvas canvas, TrackGeom geom) {
    final rnd = Random(77);
    // Trees outside the track.
    for (int i = 0; i < 10; i++) {
      final d = geom.lapLength * rnd.nextDouble();
      final side = rnd.nextBool() ? 1.0 : -1.0;
      final p = geom.worldAt(d, side * (1.55 + rnd.nextDouble() * 0.8));
      final r = 34 + rnd.nextDouble() * 26;
      canvas.drawCircle(
          p + const Offset(8, 10),
          r,
          Paint()..color = Colors.black.withValues(alpha: 0.25));
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.4),
              radius: 1.0,
              colors: [
                _shade(const Color(0xFF3E6B34), 1.25),
                const Color(0xFF2A4A24),
              ],
            ).createShader(Rect.fromCircle(center: p, radius: r)));
    }
    // Tire stacks near tight corners.
    int placed = 0;
    for (int i = 0; i < 60 && placed < 5; i++) {
      final d = geom.lapLength * i / 60;
      if (geom.cornerFactor(d) > 0.55) {
        final p = geom.worldAt(d, 1.45);
        for (int k = 0; k < 3; k++) {
          canvas.drawCircle(
            p + Offset(k * 26.0 - 26, (k % 2) * 20.0),
            20,
            Paint()..color = const Color(0xFF26262A),
          );
          canvas.drawCircle(
            p + Offset(k * 26.0 - 26 - 5, (k % 2) * 20.0 - 5),
            12,
            Paint()..color = const Color(0xFF3A3A40),
          );
        }
        placed++;
      }
    }
  }

  void _paintSkids(Canvas canvas) {
    for (final r in engine.racers) {
      for (final t in r.trail) {
        final a = (1 - t.age / 1.6).clamp(0.0, 1.0);
        if (a <= 0) continue;
        canvas.drawCircle(
          t.p,
          4 + 8 * a,
          Paint()..color = Colors.black.withValues(alpha: 0.35 * a),
        );
      }
    }
  }

  void _paintCars(Canvas canvas, TrackGeom geom) {
    final order = [...engine.racers]
      ..sort((a, b) => b.place.compareTo(a.place)); // leader painted last
    for (final r in order) {
      final pos = geom.worldAt(r.dist, r.lat);
      final t = geom.tangentAt(max(0.0, r.dist));
      final heading = atan2(t.dy, t.dx);
      // Name tag (visible opponents — every racer labeled).
      _paintTag(canvas, pos, r);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(heading + r.visualAngle);
      _paintCar(canvas, r);
      canvas.restore();
    }
  }

  void _paintTag(Canvas canvas, Offset pos, Racer r) {
    final tp = TextPainter(
      text: TextSpan(
        text: r.isBot ? r.name : '${r.name} ★',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: r.isBot ? theme.ivory : theme.accentLight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final p = pos + Offset(-tp.width / 2, -118);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(p.dx - 14, p.dy - 8, tp.width + 28, tp.height + 16),
          const Radius.circular(14)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    tp.paint(canvas, p);
  }

  void _paintCar(Canvas canvas, Racer r) {
    final body = r.color;
    final dark = _shade(body, 0.68);
    final light = _shade(body, 1.28);
    final style = CarStyles.variant(carStyle);
    final s = style == 8 ? 0.8 : 1.0; // micro is smaller
    canvas.save();
    canvas.scale(s);
    // Shadow.
    canvas.drawOval(
      const Rect.fromLTWH(-52, -24, 116, 58),
      Paint()..color = Colors.black.withValues(alpha: 0.32),
    );
    // Wheels.
    final wheelR = style == 9 ? 15.0 : 11.0; // monster truck wheels
    final wheelPaint = Paint()..color = const Color(0xFF1C1C20);
    final hubPaint = Paint()..color = const Color(0xFF6E6E78);
    for (final wx in [-30.0, 30.0]) {
      for (final wy in [-24.0, 24.0]) {
        canvas.drawCircle(Offset(wx, wy), wheelR, wheelPaint);
        canvas.drawCircle(Offset(wx, wy), wheelR * 0.45, hubPaint);
      }
    }
    // Body.
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, body, dark],
      ).createShader(const Rect.fromLTWH(-48, -22, 96, 44));
    if (style == 0) {
      // Speedster wedge.
      final p = Path()
        ..moveTo(-46, -20)
        ..lineTo(20, -22)
        ..lineTo(50, 0)
        ..lineTo(20, 22)
        ..lineTo(-46, 20)
        ..quadraticBezierTo(-52, 0, -46, -20)
        ..close();
      canvas.drawPath(p, bodyPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-48, -22, 96, 44),
            const Radius.circular(13)),
        bodyPaint,
      );
    }
    // Roof / cabin variants.
    final glass = Paint()..color = const Color(0xFF2B3542);
    if (style == 2) {
      // Buggy: open top + roll bar.
      canvas.drawArc(
          const Rect.fromLTWH(-14, -16, 28, 32), 0, pi, false,
          Paint()
            ..color = dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7);
    } else if (style != 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                style == 5 ? -18 : -22, -15, style == 5 ? 34 : 40, 30),
            const Radius.circular(8)),
        glass,
      );
    } else {
      // Wedge canopy.
      final p = Path()
        ..moveTo(-16, -13)
        ..lineTo(14, -14)
        ..lineTo(26, 0)
        ..lineTo(14, 14)
        ..lineTo(-16, 13)
        ..close();
      canvas.drawPath(p, glass);
    }
    if (style == 3) {
      // Pickup bed.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-44, -16, 26, 32),
            const Radius.circular(5)),
        Paint()..color = dark,
      );
    }
    if (style == 4) {
      // Stock car spoiler.
      canvas.drawRect(
          const Rect.fromLTWH(-56, -26, 10, 52), Paint()..color = dark);
      canvas.drawRect(
          const Rect.fromLTWH(-40, -4, 8, 8), Paint()..color = dark);
      canvas.drawRect(
          const Rect.fromLTWH(-40, 16, 8, 8), Paint()..color = dark);
    }
    if (style == 6) {
      // Taxi sign.
      canvas.drawRect(
          const Rect.fromLTWH(-10, -8, 20, 16), Paint()..color = theme.ivory);
      canvas.drawRect(
          const Rect.fromLTWH(-44, -3, 88, 6),
          Paint()..color = Colors.black.withValues(alpha: 0.25));
    }
    if (style == 7) {
      // Muscle hood scoop.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, -9, 22, 18),
            const Radius.circular(5)),
        Paint()..color = dark,
      );
    }
    // Headlights.
    final lamp = Paint()..color = const Color(0xFFF6E9B8);
    canvas.drawCircle(const Offset(44, -12), 5, lamp);
    canvas.drawCircle(const Offset(44, 12), 5, lamp);
    // Boost flame.
    if (r.boostTime > 0) {
      final flame = Path()
        ..moveTo(-48, -12)
        ..lineTo(-78, 0)
        ..lineTo(-48, 12)
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFE08A), Color(0xFFF08A24)],
          ).createShader(const Rect.fromLTWH(-78, -12, 30, 24)),
      );
    }
    // Drift smoke puffs.
    if (r.drifting) {
      final t = engine.raceTime;
      for (int i = 0; i < 3; i++) {
        final a = 0.35 + 0.2 * sin(t * 18 + i * 2.1 + r.seed * 9);
        canvas.drawCircle(
          Offset(-52 - i * 16, (i % 2 == 0 ? -1 : 1) * (10 + i * 6)),
          10 + i * 5,
          Paint()..color = Colors.white.withValues(alpha: a.clamp(0.05, 0.5)),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RacePainter oldDelegate) => true;
}
