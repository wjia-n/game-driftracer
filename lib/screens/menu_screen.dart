import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/race_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/pit_art.dart';
import '../theme/race_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';
import 'race_screen.dart';
import 'settings_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.driftracer';

/// Main menu — paddock edition.
/// Logo, mode cards (Career / Quick Race / Time Trial / Endless Drift),
/// career tiers, quick setup, renameable drivers, theme/car/track pickers,
/// share, rate, settings.
class MenuScreen extends StatefulWidget {
  final DriftAudio audio;
  final RacerSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _careerKey = GlobalKey();
  int _humans = 1;

  RacerSettings get _s => widget.settings;
  RaceThemeDef get _t => RaceThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Pit.body(15, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _startRace({
    required RaceConfig config,
    required List<String> humanNames,
    int tierIndex = -1,
  }) {
    widget.audio.gameStart();
    // App-scoped music: the race screen switches to the game track on
    // entry; we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => RaceScreen(
        audio: widget.audio,
        settings: _s,
        config: config,
        humanNames: humanNames,
        tierIndex: tierIndex,
      ),
    ))
        .then((_) {
      if (mounted) {
        widget.audio.startMenuMusic();
        setState(() {});
      }
    });
  }

  void _playQuick() {
    final s = _s;
    final humans = _humans;
    _startRace(
      config: RaceConfig(
        mode: RaceMode.quick,
        laps: humans == 1 ? s.laps : 2,
        botCount: humans == 1 ? s.botCount : 0,
        difficulty: BotDifficulty.values[s.difficulty],
      ),
      humanNames: s.driverNames.sublist(0, humans),
    );
  }

  void _playTimeTrial() {
    _startRace(
      config: const RaceConfig(mode: RaceMode.timeTrial, laps: 3),
      humanNames: [_s.driverNames[0]],
    );
  }

  void _playEndless() {
    _startRace(
      config: const RaceConfig(mode: RaceMode.endless),
      humanNames: [_s.driverNames[0]],
    );
  }

  void _playTier(int tier) {
    final s = _s;
    _startRace(
      config: RaceConfig(
        mode: RaceMode.career,
        laps: RacerSettings.tierLaps[tier],
        botCount: RacerSettings.tierBots[tier],
        difficulty:
            BotDifficulty.values[RacerSettings.tierBotDiff[tier]],
        tier: tier,
      ),
      humanNames: [s.driverNames[0]],
      tierIndex: tier,
    );
  }

  Future<void> _goPro() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: _s,
        store: _store,
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = _s;
    return PaddockBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              controller: _scroll,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                children: [
                  // Logo + title.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: t.accent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.6),
                              offset: const Offset(0, 6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset('assets/driftracer_logo.png',
                            fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Drift Racer',
                              style: Pit.display(38, theme: t)),
                          Text('TOY-CAR DRIFT CHAMPIONSHIP',
                              style: Pit.label(11, theme: t)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Mode cards.
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _ModeTile(
                        theme: t,
                        icon: Icons.emoji_events,
                        label: 'Career',
                        sub: 'Tiers & stars',
                        onTap: () {
                          widget.audio.click();
                          _scrollToCareer();
                        },
                      ),
                      _ModeTile(
                        theme: t,
                        icon: Icons.flag,
                        label: 'Quick Race',
                        sub: 'You vs rivals',
                        onTap: _playQuick,
                      ),
                      _ModeTile(
                        theme: t,
                        icon: Icons.timer,
                        label: 'Time Trial',
                        sub: 'Solo • 3 laps',
                        onTap: _playTimeTrial,
                      ),
                      _ModeTile(
                        theme: t,
                        icon: Icons.all_inclusive,
                        label: 'Endless Drift',
                        sub: '2 min score run',
                        onTap: _playEndless,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // PRO banner.
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      _goPro();
                    },
                    child: Container(
                      width: 300,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accentDark,
                        ]),
                        border: Border.all(
                            color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.isPro ? '✦  PRO ACTIVE' : '✦  Get PRO',
                        style: Pit.label(17,
                            theme: t, color: t.woodDeep),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CareerCard(
                      key: _careerKey,
                      theme: t,
                      onTier: _playTier,
                      goPro: _goPro),
                  const SizedBox(height: 14),
                  _QuickCard(theme: t),
                  const SizedBox(height: 14),
                  _NamesCard(theme: t),
                  const SizedBox(height: 14),
                  _ThemeCard(theme: t, goPro: _goPro),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          await SharePlus.instance.share(ShareParams(
                            text:
                                'Drift Racer — drift, chain and boost past your rivals! 🏁 $_storeUrl',
                          ));
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statsLine(s),
                    style: Pit.label(12, theme: t),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Pit.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statsLine(RacerSettings s) {
    final parts = <String>[];
    if (s.gamesPlayed > 0) {
      parts.add('Wins: ${s.wins}');
      parts.add('Races: ${s.gamesPlayed}');
    }
    if (s.bestLapMs > 0) {
      final sec = s.bestLapMs / 1000;
      parts.add(
          'Best lap: ${sec.toStringAsFixed(1)}s');
    }
    if (s.bestEndless > 0) parts.add('Best drift: ${s.bestEndless}');
    return parts.isEmpty ? 'Finish a race to start your record book!' : parts.join('   •   ');
  }

  void _scrollToCareer() {
    final ctx = _careerKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 450));
    }
  }

  void _showHowTo(BuildContext context, RaceThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Pit.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Drag left/right anywhere to steer your car.',
                  '• HOLD the skid button while turning to DRIFT.',
                  '• Drifting builds boost charge — release for a speed boost!',
                  '• Chain drifts without touching grass for multipliers.',
                  '• Grass slows you down and breaks your chain.',
                  '• Smacking the fence costs speed — stay smooth.',
                  '• Finish the laps ahead of your rivals to win.',
                  '• Career: win a tier to unlock the next and earn stars.',
                  '• Time Trial: 3 solo laps, chase your best.',
                  '• Endless Drift: 2 minutes, pure drift score.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Pit.body(14, theme: t)),
                  ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: PitButton(
                    label: 'Got it!',
                    width: 150,
                    fontSize: 16,
                    theme: t,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ModeTile extends StatelessWidget {
  final RaceThemeDef theme;
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _ModeTile(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.sub,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDark],
          ),
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: t.accentLight, size: 34),
            const SizedBox(height: 8),
            Text(label,
                style: Pit.label(15, theme: t),
                textAlign: TextAlign.center),
            Text(sub,
                style: Pit.body(11,
                    theme: t, color: t.ivory.withValues(alpha: 0.65)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final RaceThemeDef theme;
  final String title;
  final Widget child;
  const _Card(
      {required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.woodMid.withValues(alpha: 0.85),
            t.woodDeep.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: t.accent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Pit.display(20, theme: t)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final RaceThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? t.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? t.accentLight
                : t.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Pit.label(13,
              theme: t, color: selected ? t.woodDeep : t.ivory),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Career tiers with stars and locks.
class _CareerCard extends StatelessWidget {
  final RaceThemeDef theme;
  final ValueChanged<int> onTier;
  final Future<void> Function() goPro;
  const _CareerCard(
      {super.key,
      required this.theme,
      required this.onTier,
      required this.goPro});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Career Tiers',
      child: Column(
        children: [
          for (int i = 0; i < 4; i++)
            Builder(builder: (_) {
              final locked = i > s.tierUnlocked ||
                  (i == 3 && !s.isPro);
              final stars = s.tierStars[i];
              return GestureDetector(
                onTap: () async {
                  audio.click();
                  if (locked) {
                    if (i == 3 && !s.isPro) {
                      await goPro();
                      return;
                    }
                    audio.invalid();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Win ${RacerSettings.tierNames[s.tierUnlocked]} first!',
                            style: Pit.body(14, theme: theme)),
                        backgroundColor: theme.woodDeep,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  onTier(i);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: locked
                        ? Colors.black.withValues(alpha: 0.35)
                        : theme.accent.withValues(alpha: 0.14),
                    border: Border.all(
                        color: locked
                            ? theme.accent.withValues(alpha: 0.25)
                            : theme.accent,
                        width: locked ? 1.2 : 2),
                  ),
                  child: Row(
                    children: [
                      Text(locked ? '🔒' : '🏁',
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${RacerSettings.tierNames[i]}${i == 3 ? '  ✦PRO' : ''}',
                                style: Pit.label(15, theme: theme)),
                            Text(RacerSettings.tierBlurbs[i],
                                style: Pit.body(12,
                                    theme: theme,
                                    color: theme.ivory
                                        .withValues(alpha: 0.65))),
                          ],
                        ),
                      ),
                      Text(
                        stars > 0
                            ? '★' * stars + '☆' * (3 - stars)
                            : '☆☆☆',
                        style: TextStyle(
                            fontSize: 16,
                            color: theme.accentLight),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Quick-race setup: humans, bots, difficulty, laps.
class _QuickCard extends StatelessWidget {
  final RaceThemeDef theme;
  const _QuickCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    const difficulties = ['Easy', 'Medium', 'Hard'];
    return _Card(
      theme: theme,
      title: 'Quick Race Setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Drivers (pass-and-play):',
              style: Pit.body(14, theme: theme)),
          const SizedBox(height: 4),
          Wrap(
            children: [
              for (int h = 1; h <= 4; h++)
                _Chip(
                  theme: theme,
                  label: '$h',
                  selected: screen._humans == h,
                  onTap: () {
                    audio.click();
                    screen.setState(() => screen._humans = h);
                  },
                ),
            ],
          ),
          if (screen._humans > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Hot-seat: each driver races 2 solo laps in turn — fastest total time wins.',
                style: Pit.body(12,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.65)),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            Text('Rival racers:', style: Pit.body(14, theme: theme)),
            const SizedBox(height: 4),
            Wrap(
              children: [
                for (int b = 1; b <= 3; b++)
                  _Chip(
                    theme: theme,
                    label: '$b',
                    selected: s.botCount == b,
                    onTap: () {
                      audio.click();
                      s.setQuickSetup(
                          bots: b,
                          difficulty: s.difficulty,
                          laps: s.laps);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Rival skill:', style: Pit.body(14, theme: theme)),
            const SizedBox(height: 4),
            Wrap(
              children: [
                for (int d = 0; d < 3; d++)
                  _Chip(
                    theme: theme,
                    label:
                        '${d == 2 && !s.isPro ? '🔒 ' : ''}${difficulties[d]}',
                    selected: s.difficulty == d,
                    onTap: () async {
                      audio.click();
                      if (d == 2 && !s.isPro) {
                        await screen._goPro();
                        return;
                      }
                      s.setQuickSetup(
                          bots: s.botCount,
                          difficulty: d,
                          laps: s.laps);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Laps:', style: Pit.body(14, theme: theme)),
            const SizedBox(height: 4),
            Wrap(
              children: [
                for (int l = 1; l <= 5; l++)
                  _Chip(
                    theme: theme,
                    label: '$l',
                    selected: s.laps == l,
                    onTap: () {
                      audio.click();
                      s.setQuickSetup(
                          bots: s.botCount,
                          difficulty: s.difficulty,
                          laps: l);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: PitButton(
              label: '🏁  Start Race',
              width: 240,
              theme: theme,
              onTap: screen._playQuick,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Renameable driver slots. Saves on EVERY keystroke (never setStringList —
/// one order-preserving JSON string) and commits on focus loss.
class _NamesCard extends StatelessWidget {
  final RaceThemeDef theme;
  const _NamesCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return _Card(
      theme: theme,
      title: 'Driver Names',
      child: Column(
        children: [
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.playerColors[i],
                      border: Border.all(
                          color: theme.accentLight, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NameField(
                      theme: theme,
                      index: i,
                      initial: s.driverNames[i],
                      role: i == 0 ? 'You' : 'Rival ${i + 1}',
                      onChanged: (v) => s.setDriverName(i, v),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Names show above cars, on the podium and in race narration.',
            style: Pit.body(12,
                theme: theme,
                color: theme.ivory.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final RaceThemeDef theme;
  final int index;
  final String initial;
  final String role;
  final ValueChanged<String> onChanged;
  const _NameField({
    required this.theme,
    required this.index,
    required this.initial,
    required this.role,
    required this.onChanged,
  });

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _f;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _f = FocusNode();
    // Save on EVERY keystroke — never wait for keyboard-done.
    _c.addListener(() => widget.onChanged(_c.text));
    // Commit on focus loss (belt and suspenders).
    _f.addListener(() {
      if (!_f.hasFocus) widget.onChanged(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    // Sync external changes (e.g. reset) without clobbering active typing.
    if (widget.initial != old.initial &&
        widget.initial != _c.text &&
        !_f.hasFocus) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return TextField(
      controller: _c,
      focusNode: _f,
      maxLength: 14,
      style: Pit.body(15, theme: t),
      decoration: InputDecoration(
        counterText: '',
        labelText: widget.role,
        labelStyle:
            Pit.body(12, theme: t, color: t.ivory.withValues(alpha: 0.55)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: t.accent.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.accentLight, width: 2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Theme / car / track pickers with PRO locks.
class _ThemeCard extends StatelessWidget {
  final RaceThemeDef theme;
  final Future<void> Function() goPro;
  const _ThemeCard({required this.theme, required this.goPro});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return _Card(
      theme: theme,
      title: 'Pit Style',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final th in RaceThemes.all)
                _ThemeTile(
                  theme: theme,
                  th: th,
                  selected: s.themeId == th.id,
                  locked:
                      RaceThemes.isProTheme(th.id) && !isPro,
                  onTap: () {
                    audio.click();
                    if (RaceThemes.isProTheme(th.id) && !isPro) {
                      goPro();
                      return;
                    }
                    s.setTheme(th.id);
                  },
                ),
              _ThemeTile(
                theme: theme,
                th: s.customTheme,
                selected: s.themeId == 'custom',
                locked: !isPro,
                custom: true,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    goPro();
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${RaceThemes.all.length - RaceThemes.freeThemeIds.length} more themes in PRO',
                style: Pit.label(12, theme: theme),
              ),
            ),
          const SizedBox(height: 14),
          Text('Car style:', style: Pit.body(14, theme: theme)),
          const SizedBox(height: 4),
          Wrap(
            children: [
              for (int i = 0; i < CarStyles.names.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${CarStyles.isPro(i) && !isPro ? '🔒 ' : ''}${CarStyles.names[i]}',
                  selected: s.carStyle == i,
                  onTap: () {
                    audio.click();
                    if (CarStyles.isPro(i) && !isPro) {
                      goPro();
                      return;
                    }
                    s.setCarStyle(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Track layout:', style: Pit.body(14, theme: theme)),
          const SizedBox(height: 4),
          Wrap(
            children: [
              for (int i = 0; i < TrackStyles.names.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${TrackStyles.isPro(i) && !isPro ? '🔒 ' : ''}${TrackStyles.names[i]}',
                  selected: s.trackStyle == i,
                  onTap: () {
                    audio.click();
                    if (TrackStyles.isPro(i) && !isPro) {
                      goPro();
                      return;
                    }
                    s.setTrackStyle(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final RaceThemeDef theme;
  final RaceThemeDef th;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.theme,
    required this.th,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: [
                th.woodMid,
                th.felt,
              ]),
              border: Border.all(
                color: selected
                    ? th.accentLight
                    : th.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in th.playerColors)
                      Container(
                        width: 13,
                        height: 13,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                              color: th.accentLight, width: 1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  custom ? '🎨 My Creation' : th.name,
                  style: Pit.label(10, theme: th),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 104,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock,
                  color: theme.accentLight, size: 22),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final RaceThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.accentDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: t.woodDeep, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: Pit.label(11, theme: t)),
        ],
      ),
    );
  }
}
