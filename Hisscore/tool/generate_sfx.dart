// Synthesizes short retro "8-bit" sound effects as WAV files, so the
// game has real audio without depending on any external/downloaded
// asset. Run with: dart run tool/generate_sfx.dart
//
// Each effect is a simple square/sine tone (or a short sequence of
// them) written as 16-bit PCM mono WAV — the classic chiptune-blip
// sound, matching the game's CRT/arcade theme.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _sampleRate = 22050;

void main() {
  Directory('assets/sfx').createSync(recursive: true);

  _write('eat', _tones([_Tone(880, 60, _Wave.square)]));
  _write(
    'bonus',
    _tones([_Tone(660, 50, _Wave.square), _Tone(990, 70, _Wave.square)]),
  );
  _write(
    'levelup',
    _tones([
      _Tone(523, 60, _Wave.square),
      _Tone(659, 60, _Wave.square),
      _Tone(784, 60, _Wave.square),
      _Tone(1047, 110, _Wave.square),
    ]),
  );
  _write(
    'gameover',
    _tones([
      _Tone(392, 100, _Wave.sine),
      _Tone(330, 100, _Wave.sine),
      _Tone(262, 220, _Wave.sine),
    ]),
  );

  // A scrape survived: a low catch of breath, then the relief. Sine,
  // and quiet in shape, so it reads as "phew" rather than "reward" —
  // it fires next to a wall, where the player is already tense.
  _write(
    'closecall',
    _tones([_Tone(294, 45, _Wave.sine), _Tone(494, 95, _Wave.sine)]),
  );

  // Beating your own best, mid-run. Deliberately higher and brighter
  // than levelup, which it will sometimes land next to.
  _write(
    'newbest',
    _tones([
      _Tone(784, 50, _Wave.square),
      _Tone(988, 50, _Wave.square),
      _Tone(1319, 50, _Wave.square),
      _Tone(1568, 140, _Wave.square),
    ]),
  );

  // Pickup stingers, one per power-up so they can be told apart by ear.
  _write(
    'star',
    _tones([
      _Tone(880, 45, _Wave.square),
      _Tone(1175, 45, _Wave.square),
      _Tone(1568, 90, _Wave.square),
    ]),
  );
  _write(
    'shield',
    _tones([
      _Tone(392, 70, _Wave.sine),
      _Tone(587, 70, _Wave.sine),
      _Tone(784, 150, _Wave.sine),
    ]),
  );
  _write(
    'speed',
    _tones([
      for (var i = 0; i < 8; i++) _Tone(400 + i * 170, 22, _Wave.square),
    ]),
  );
  _write(
    'shrink',
    _tones([for (var i = 0; i < 6; i++) _Tone(1000 - i * 120, 36, _Wave.sine)]),
  );
  _write(
    'magnet',
    _tones([
      for (var i = 0; i < 6; i++) _Tone(i.isEven ? 600 : 800, 32, _Wave.square),
    ]),
  );

  stdout.writeln('Wrote assets/sfx/*.wav');

  _writeMusic();
}

// ─── Music ────────────────────────────────────────────
//
// A four-bar loop in A minor (Am F C G) at 140 BPM, rendered as three
// layers of identical length so the game can play them together and
// fade layers in as the combo climbs: bass always, arpeggio + hats from
// combo 2, lead melody from combo 4.

const _bpm = 140;
final _eighth = (_sampleRate * 60 / _bpm / 2).round();
final _sixteenth = _eighth ~/ 2;
final _loopLength = _eighth * 8 * 4;

void _writeMusic() {
  Directory('assets/music').createSync(recursive: true);

  final bass = Float32List(_loopLength);
  final arp = Float32List(_loopLength);
  final lead = Float32List(_loopLength);

  // Bass: root, root, octave pulses on each eighth.
  const roots = [110.0, 87.31, 130.81, 98.0];
  const bassPattern = [1, 1, 2, 1, 1, 2, 1, 2];
  for (var bar = 0; bar < 4; bar++) {
    for (var e = 0; e < 8; e++) {
      _note(
        bass,
        (bar * 8 + e) * _eighth,
        roots[bar] * bassPattern[e],
        _eighth * 0.9,
        0.32,
      );
    }
  }

  // Arpeggio: sixteenth notes walking each bar's chord, plus a closed
  // hat on every off-beat eighth.
  const chords = [
    [220.0, 261.63, 329.63],
    [174.61, 220.0, 261.63],
    [261.63, 329.63, 392.0],
    [196.0, 246.94, 293.66],
  ];
  const arpPattern = [0, 1, 2, 1];
  for (var bar = 0; bar < 4; bar++) {
    for (var s = 0; s < 16; s++) {
      _note(
        arp,
        (bar * 16 + s) * _sixteenth,
        chords[bar][arpPattern[s % 4]],
        _sixteenth * 0.8,
        0.16,
        duty: 0.25,
      );
    }
    for (var e = 1; e < 8; e += 2) {
      _hat(arp, (bar * 8 + e) * _eighth, 0.12);
    }
  }

  // Lead: a simple hook, one bar per chord. 0 is a rest.
  const melody = [
    [659.25, 0.0, 523.25, 659.25, 880.0, 0.0, 783.99, 659.25],
    [698.46, 0.0, 523.25, 698.46, 880.0, 0.0, 783.99, 698.46],
    [659.25, 0.0, 523.25, 659.25, 783.99, 0.0, 659.25, 523.25],
    [587.33, 0.0, 493.88, 587.33, 783.99, 0.0, 698.46, 587.33],
  ];
  for (var bar = 0; bar < 4; bar++) {
    for (var e = 0; e < 8; e++) {
      final hz = melody[bar][e];
      if (hz == 0) continue;
      _note(lead, (bar * 8 + e) * _eighth, hz, _eighth * 0.85, 0.22);
    }
  }

  File('assets/music/bass.wav').writeAsBytesSync(_encodeWav(bass));
  File('assets/music/arp.wav').writeAsBytesSync(_encodeWav(arp));
  File('assets/music/lead.wav').writeAsBytesSync(_encodeWav(lead));
  stdout.writeln('Wrote assets/music/*.wav');
}

/// Mixes one pulse-wave note into [buf] at sample [start].
void _note(
  Float32List buf,
  int start,
  double hz,
  double lengthSamples,
  double amp, {
  double duty = 0.5,
}) {
  final n = lengthSamples.round();
  for (var i = 0; i < n; i++) {
    final at = start + i;
    if (at >= buf.length) break;
    final phase = (hz * i / _sampleRate) % 1.0;
    final wave = phase < duty ? 1.0 : -1.0;
    // Short attack to avoid a click, then a decay to silence so notes
    // (and the loop seam) end at zero.
    final attack = (i / 60).clamp(0.0, 1.0);
    final decay = 1.0 - i / n;
    buf[at] += wave * amp * attack * decay;
  }
}

/// Mixes a short burst of noise (a hi-hat) into [buf] at sample [start].
void _hat(Float32List buf, int start, double amp) {
  final random = Random(start);
  final n = (_sampleRate * 0.03).round();
  for (var i = 0; i < n; i++) {
    final at = start + i;
    if (at >= buf.length) break;
    buf[at] += (random.nextDouble() * 2 - 1) * amp * (1.0 - i / n);
  }
}

void _write(String name, Float32List samples) {
  File('assets/sfx/$name.wav').writeAsBytesSync(_encodeWav(samples));
}

enum _Wave { sine, square }

class _Tone {
  const _Tone(this.hz, this.ms, this.wave);
  final double hz;
  final int ms;
  final _Wave wave;
}

/// Renders a sequence of tones back-to-back into one sample buffer,
/// with a short linear fade-out on each tone to avoid audible clicks.
Float32List _tones(List<_Tone> tones) {
  final chunks = <Float32List>[];
  for (final t in tones) {
    final n = (_sampleRate * t.ms / 1000).round();
    final buf = Float32List(n);
    for (var i = 0; i < n; i++) {
      final phase = 2 * pi * t.hz * i / _sampleRate;
      final raw = switch (t.wave) {
        _Wave.sine => sin(phase),
        _Wave.square => sin(phase) >= 0 ? 1.0 : -1.0,
      };
      final fadeOut = 1.0 - (i / n) * 0.6; // gentle decay, no hard cutoff
      buf[i] = raw * 0.5 * fadeOut;
    }
    chunks.add(buf);
  }
  final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
  final out = Float32List(total);
  var offset = 0;
  for (final c in chunks) {
    out.setAll(offset, c);
    offset += c.length;
  }
  return out;
}

/// Encodes mono float samples (-1..1) as a 16-bit PCM WAV file.
Uint8List _encodeWav(Float32List samples) {
  const bitsPerSample = 16;
  const numChannels = 1;
  final byteRate = _sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataSize = samples.length * 2;

  final buffer = BytesBuilder();
  void writeString(String s) => buffer.add(s.codeUnits);
  void writeU32(int v) => buffer.add([
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ]);
  void writeU16(int v) => buffer.add([v & 0xFF, (v >> 8) & 0xFF]);

  writeString('RIFF');
  writeU32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeU32(16);
  writeU16(1); // PCM
  writeU16(numChannels);
  writeU32(_sampleRate);
  writeU32(byteRate);
  writeU16(blockAlign);
  writeU16(bitsPerSample);
  writeString('data');
  writeU32(dataSize);
  for (final s in samples) {
    final clamped = s.clamp(-1.0, 1.0);
    final intSample = (clamped * 32767).round();
    writeU16(intSample & 0xFFFF);
  }
  return buffer.toBytes();
}
