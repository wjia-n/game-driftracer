import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Drift Racer — all sounds synthesized in code as WAV
/// bytes. No asset files. Greasy-pit-stop energy: engine growls, tire
/// screeches, crash thuds, boost whooshes.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Clips are synthesized ONCE and cached.
/// - A [_musicGen] generation counter serializes track changes: the LATEST
///   request always wins; overlapping calls can never swallow a start or
///   leave the player half-started — music is app-scoped and never dies.
/// - Lifecycle uses pause()/resume() so an interruption resumes where it
///   left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class DriftAudio {
  /// Per-game pitch character (driftracer): 1.34x. Makes SFX unique.
  static const double _pitchMul = 1.340;

  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _loop = AudioPlayer(); // engine / drift loops
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  // Loop-channel state (engine hum / tire screech during races).
  String? _loopClip;
  int _loopGen = 0;

  DriftAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
    _loop.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    _loop.setVolume(sfxOn ? volume * 0.5 : 0.0);
    if (!musicOn) {
      stopMusic();
    }
    if (!sfxOn) {
      stopLoop();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
    _engineLoopBytes();
    _screechLoopBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    freq *= _pitchMul;
    freqEnd *= _pitchMul;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _noiseBurst(double secs, double cutoff,
      {double decay = 25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    double last = 0;
    final k = exp(-2 * pi * cutoff / _rate);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final w = _rand.nextDouble() * 2 - 1;
      last = last * k + w * (1 - k);
      out[i] = _env(i, n, attack: 0.005) * last * 2 * exp(-t * decay);
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // B arpeggiated 0 – 4 – 5 – 3, 16s loop. Unique to driftracer.
        final notes = [246.94, 311.12, 369.99, 311.12, 369.99, 466.16, 554.36, 466.16, 415.30, 493.88, 622.25, 493.88, 329.63, 415.30, 493.88, 415.30];
        final out = <double>[];
        final noteLen = 16.0 / notes.length;
        for (final n in notes) {
          out.addAll(_tone(n, noteLen * 0.9, harmonics: 0.3));
          final gap = List<double>.filled((_rate * noteLen * 0.1).round(), 0);
          out.addAll(gap);
        }
        // Soft pad underneath
        final pad = _padChord([246.94, 311.12, 369.99], 16.0);
        for (int i = 0; i < out.length && i < pad.length; i++) {
          out[i] += pad[i] * 0.3;
        }
        return out;
      });


  Uint8List _gameBytes() => _clip('music_game', () {
        // B 0 – 4 – 5 – 3 warm pad, 16s loop. Unique to driftracer.
        final seq = [
          [246.94, 311.12, 369.99],
          [369.99, 466.16, 554.36],
          [415.30, 493.88, 622.25],
          [329.63, 415.30, 493.88]
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });


  /// Looping engine hum (seamless-ish loop, engine-y growl).
  Uint8List _engineLoopBytes() => _clip('loop_engine', () {
        const secs = 1.6;
        final n = (_rate * secs).round();
        final out = List<double>.filled(n, 0);
        for (int i = 0; i < n; i++) {
          final t = i / _rate;
          // Low growl: fundamental + harmonics, slight RPM wobble.
          final rpm = 1 + 0.06 * sin(2 * pi * 1.25 * t);
          final f = 68.0 * rpm;
          double v = sin(2 * pi * f * t) +
              0.5 * sin(2 * pi * f * 2 * t) +
              0.25 * sin(2 * pi * f * 3 * t) +
              0.12 * (_rand.nextDouble() * 2 - 1);
          // Crossfade the loop seam.
          final edge = (0.06 * n).round();
          double fade = 1.0;
          if (i < edge) {
            fade = i / edge;
          } else if (i >= n - edge) {
            fade = (n - 1 - i) / edge;
          }
          out[i] = v * 0.28 * fade;
        }
        return out;
      });

  /// Looping tire screech bed while drifting.
  Uint8List _screechLoopBytes() => _clip('loop_screech', () {
        const secs = 1.2;
        final n = (_rate * secs).round();
        final out = List<double>.filled(n, 0);
        double last = 0;
        const k = 0.86;
        for (int i = 0; i < n; i++) {
          final t = i / _rate;
          final w = _rand.nextDouble() * 2 - 1;
          last = last * k + w * (1 - k);
          final whistle = sin(2 * pi * (2100 + 400 * sin(2 * pi * 7 * t)) * t);
          double v = (last * 2.2 + 0.25 * whistle) * 0.30;
          final edge = (0.08 * n).round();
          double fade = 1.0;
          if (i < edge) {
            fade = i / edge;
          } else if (i >= n - edge) {
            fade = (n - 1 - i) / edge;
          }
          out[i] = v * fade;
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> invalid() => _play(
      _clip('invalid', () => _tone(140, 0.18, harmonics: 0.5)));
  Future<void> countdownBeep() =>
      _play(_clip('beep', () => _tone(660, 0.14)));
  Future<void> go() =>
      _play(_clip('go', () => _tone(660, 0.5, freqEnd: 1320)));
  Future<void> engineRev() =>
      _play(_clip('rev', () => _tone(70, 0.7, freqEnd: 210, harmonics: 0.6)));
  Future<void> boost() =>
      _play(_clip('boost', () => _noiseBurst(0.45, 3200, decay: 8)));
  Future<void> crash() => _play(_clip('crash', () {
        final thud = _tone(90, 0.4, freqEnd: 40, harmonics: 0.6);
        final smash = _noiseBurst(0.35, 900, decay: 14);
        final n = max(thud.length, smash.length);
        final out = List<double>.filled(n, 0);
        for (int i = 0; i < n; i++) {
          out[i] =
              (i < thud.length ? thud[i] : 0) + (i < smash.length ? smash[i] * 0.8 : 0);
        }
        return out;
      }));
  Future<void> lap() =>
      _play(_clip('lap', () => _arp([783.99, 1046.5], 0.12, 0.02)));
  Future<void> gameStart() => _play(
      _clip('start', () => _tone(330, 0.35, freqEnd: 660, harmonics: 0.4)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));
  Future<void> record() => _play(_clip(
      'record', () => _arp([659.25, 783.99, 1046.5, 1318.5, 1568.0], 0.14, 0.02)));

  // ------------------------------------------------------------ loop SFX
  /// Start a seamless-ish loop clip on the loop channel (engine hum while
  /// racing, screech bed while drifting). Serialized with a generation
  /// counter so overlapping requests can't desync it.
  Future<void> _startLoop(String key, Uint8List bytes) async {
    if (_disposed) return;
    final gen = ++_loopGen;
    if (_loopClip == key) return; // already looping this clip
    try {
      await _loop.stop();
      if (gen != _loopGen || _disposed || !sfxOn) return;
      _loopClip = key;
      await _loop.play(BytesSource(bytes));
    } catch (_) {
      if (gen == _loopGen) _loopClip = null;
    }
  }

  Future<void> startEngineLoop() =>
      _startLoop('loop_engine', _engineLoopBytes());
  Future<void> startScreechLoop() =>
      _startLoop('loop_screech', _screechLoopBytes());

  Future<void> stopLoop() async {
    ++_loopGen;
    if (_disposed) return;
    try {
      await _loop.stop();
    } catch (_) {}
    _loopClip = null;
  }

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed) return;
    try {
      await _music.pause();
      await _loop.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      if (musicOn && _currentTrack != null) {
        await _music.resume();
      }
      if (sfxOn && _loopClip != null) {
        await _loop.resume();
      }
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
      await _loop.dispose();
    } catch (_) {}
  }
}
