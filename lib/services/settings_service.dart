import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/race_themes.dart';

/// Persisted settings + stats for Drift Racer. Survives app restarts.
///
/// Stores: audio toggles, driver profile (renameable, ONE JSON string —
/// never setStringList: Android stores StringLists as an unordered StringSet
/// and scrambles order), theme/car/track choices (incl. custom theme
/// colors), career progress, mode setup, Pro unlock state, lifetime stats.
class RacerSettings extends ChangeNotifier {
  static const _kMusic = 'drift_music_on';
  static const _kSfx = 'drift_sfx_on';
  static const _kVolume = 'drift_volume';
  static const _kNamesLegacyList =
      'drift_driver_names'; // v1: unordered StringSet key (scrambled order)
  static const _kNamesLegacyJson =
      'drift_driver_names_json'; // v2: interim JSON key
  /// Order-safe driver-name storage: a single JSON string. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'driftracer_player_names_json';
  static const _kTheme = 'drift_theme_id';
  static const _kCarStyle = 'drift_car_style';
  static const _kTrackStyle = 'drift_track_style';
  static const _kBots = 'drift_bot_count';
  static const _kDifficulty = 'drift_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kLaps = 'drift_laps';
  static const _kTier = 'drift_tier_unlocked'; // 0..3
  static const _kStars = 'drift_tier_stars_json'; // [0..3, ...] length 4
  static const _kWins = 'drift_wins';
  static const _kGames = 'drift_games_played';
  static const _kBestLap = 'drift_best_lap_ms'; // 0 = none
  static const _kBestEndless = 'drift_best_endless'; // points
  static const _kIsPro = 'drift_is_pro';
  static const _kReviewAsked = 'drift_review_asked';
  static const _kCustomPrefix = 'drift_custom_';

  static const defaultNames = ['Rookie', 'Turbo', 'Skids', 'Nitro'];

  static String encodeNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  static List<String> decodeNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 4) {
        return [for (int i = 0; i < 4; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  /// Career tiers: name, bots, bot difficulty, laps. Champion is Pro-gated.
  static const List<String> tierNames = ['Novice', 'Amateur', 'Pro Cup', 'Champion'];
  static const List<int> tierBots = [1, 2, 3, 3];
  static const List<int> tierBotDiff = [0, 1, 1, 2];
  static const List<int> tierLaps = [2, 3, 4, 4];
  static const List<String> tierBlurbs = [
    'One easy rival. Learn the ropes.',
    'Two medium rivals. 3 laps.',
    'Three medium rivals. 4 laps.',
    'Three HARD rivals. 4 laps. Legends only.',
  ];

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  List<String> driverNames = List.of(defaultNames);
  String themeId = 'park';
  int carStyle = 0;
  int trackStyle = 0;
  int botCount = 2;
  int difficulty = 1; // medium default
  int laps = 3;
  int tierUnlocked = 0;
  List<int> tierStars = [0, 0, 0, 0];
  int wins = 0;
  int gamesPlayed = 0;
  int bestLapMs = 0;
  int bestEndless = 0;
  bool isPro = true; // everything unlocked — no Pro version
  bool reviewAsked = false;

  Map<String, int> customColors = Map.of(CustomKeys.defaults);

  RaceThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return RaceThemeDef(
      id: 'custom',
      name: 'My Creation',
      woodDark: c('ground'),
      woodMid: c('groundMid'),
      woodDeep: c('groundDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      felt: c('grass'),
      trackLight: c('trackLight'),
      trackDark: c('trackDark'),
      playerColors: [c('pc0'), c('pc1'), c('pc2'), c('pc3')],
      playerColorNames: const ['One', 'Two', 'Three', 'Four'],
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Driver names: prefer the canonical order-safe JSON key; migrate once
    // from either legacy key (unordered StringList or interim JSON key).
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      driverNames = decodeNames(namesRaw);
    } else {
      final interim = p.getString(_kNamesLegacyJson);
      if (interim != null) {
        driverNames = decodeNames(interim);
      } else {
        final legacy = p.getStringList(_kNamesLegacyList);
        driverNames = (legacy != null && legacy.length == 4)
            ? [for (int i = 0; i < 4; i++) _cleanName(i, legacy[i])]
            : List.of(defaultNames);
      }
    }
    themeId = p.getString(_kTheme) ?? 'park';
    carStyle = (p.getInt(_kCarStyle) ?? 0).clamp(0, CarStyles.names.length - 1);
    trackStyle =
        (p.getInt(_kTrackStyle) ?? 0).clamp(0, TrackStyles.names.length - 1);
    botCount = (p.getInt(_kBots) ?? 2).clamp(1, 3);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    laps = (p.getInt(_kLaps) ?? 3).clamp(1, 5);
    tierUnlocked = (p.getInt(_kTier) ?? 0).clamp(0, 3);
    tierStars = _decodeStars(p.getString(_kStars));
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestLapMs = p.getInt(_kBestLap) ?? 0;
    bestEndless = p.getInt(_kBestEndless) ?? 0;
    isPro = true; // everything unlocked
    reviewAsked = p.getBool(_kReviewAsked) ?? false;
    for (final k in CustomKeys.defaults.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? CustomKeys.defaults[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  static List<int> _decodeStars(String? raw) {
    if (raw == null) return [0, 0, 0, 0];
    try {
      final d = jsonDecode(raw);
      if (d is List) {
        final out = [0, 0, 0, 0];
        for (int i = 0; i < 4 && i < d.length; i++) {
          out[i] = (d[i] is int ? d[i] as int : 0).clamp(0, 3);
        }
        return out;
      }
    } catch (_) {}
    return [0, 0, 0, 0];
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kNamesJson, encodeNames(driverNames));
    await p.remove(_kNamesLegacyList); // drop legacy unordered keys for good
    await p.remove(_kNamesLegacyJson);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kCarStyle, carStyle);
    await p.setInt(_kTrackStyle, trackStyle);
    await p.setInt(_kBots, botCount);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kLaps, laps);
    await p.setInt(_kTier, tierUnlocked);
    await p.setString(_kStars, jsonEncode(tierStars));
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestLap, bestLapMs);
    await p.setInt(_kBestEndless, bestEndless);
    await p.setBool(_kIsPro, isPro);
    await p.setBool(_kReviewAsked, reviewAsked);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || RaceThemes.isProTheme(themeId)) {
      themeId = 'park';
      changed = true;
    }
    if (CarStyles.isPro(carStyle)) {
      carStyle = 0;
      changed = true;
    }
    if (TrackStyles.isPro(trackStyle)) {
      trackStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (tierUnlocked > 2) {
      tierUnlocked = 2;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!CustomKeys.defaults.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(CustomKeys.defaults);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setDriverName(int index, String name) async {
    if (index < 0 || index > 3) return;
    final clean = name.trim();
    driverNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || RaceThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCarStyle(int v) async {
    v = v.clamp(0, CarStyles.names.length - 1);
    if (!isPro && CarStyles.isPro(v)) return;
    carStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTrackStyle(int v) async {
    v = TrackStyles.clampIndex(v);
    if (!isPro && TrackStyles.isPro(v)) return;
    trackStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setQuickSetup(
      {required int bots, required int difficulty, required int laps}) async {
    botCount = bots.clamp(1, 3);
    this.difficulty = difficulty.clamp(0, 2);
    if (!isPro && this.difficulty > 1) this.difficulty = 1;
    this.laps = laps.clamp(1, 5);
    notifyListeners();
    await _save();
  }

  /// Record a quick-race result (wins/games only — lap records untouched).
  Future<void> recordQuickRace({required bool won}) async {
    gamesPlayed++;
    if (won) wins++;
    notifyListeners();
    await _save();
  }

  /// Record a tier race result. Returns true when the win unlocks the next tier.
  Future<bool> recordTierRace(
      {required int tier, required int place, required bool humanWon}) async {
    gamesPlayed++;
    var unlockedNext = false;
    if (humanWon) {
      wins++;
      final stars = switch (place) {
        1 => 3,
        2 => 2,
        _ => 1,
      };
      if (stars > tierStars[tier]) tierStars[tier] = stars;
      if (place == 1 && tier == tierUnlocked && tier < 3) {
        tierUnlocked = tier + 1;
        unlockedNext = true;
      }
    }
    notifyListeners();
    await _save();
    return unlockedNext;
  }

  /// Record a time-trial or endless result. Returns true if a new record.
  Future<bool> recordTimeTrial(int lapMs) async {
    gamesPlayed++;
    var record = false;
    if (bestLapMs == 0 || lapMs < bestLapMs) {
      bestLapMs = lapMs;
      record = true;
    }
    notifyListeners();
    await _save();
    return record;
  }

  Future<bool> recordEndless(int score) async {
    gamesPlayed++;
    var record = false;
    if (score > bestEndless) {
      bestEndless = score;
      record = true;
    }
    notifyListeners();
    await _save();
    return record;
  }

  Future<void> markReviewAsked() async {
    reviewAsked = true;
    await _save();
  }
}
