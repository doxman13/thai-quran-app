import 'dart:math' as math;
import 'dart:typed_data';

class MelBin {
  final int start;
  final Float64List weights;

  const MelBin(this.start, this.weights);
}

class TilawaFbank {
  static const int sampleRate = 16000;
  static const int win = 400;
  static const int hop = 160;
  static const int nfft = 512;
  static const int mels = 80;
  static const double eps = 1.1920928955078125e-7;

  static double _mel(double hz) => 1127.0 * math.log(1.0 + hz / 700.0);

  static final Float64List _povey = () {
    final list = Float64List(win);
    for (int i = 0; i < win; i++) {
      list[i] = math.pow(0.5 - 0.5 * math.cos((2.0 * math.pi * i) / (win - 1)), 0.85).toDouble();
    }
    return list;
  }();

  static List<MelBin> makeMelBank([double highFrequency = 7600.0]) {
    final lo = _mel(20.0);
    final hi = _mel(highFrequency);
    final step = (hi - lo) / (mels + 1);

    return List<MelBin>.generate(mels, (m) {
      final l = lo + m * step;
      final c = lo + (m + 1) * step;
      final r = lo + (m + 2) * step;
      final bins = <int>[];
      final weights = <double>[];
      for (int k = 0; k < nfft ~/ 2; k++) {
        final f = _mel((k * sampleRate) / nfft);
        final v = math.min((f - l) / (c - l), (r - f) / (r - c));
        if (v > 0) {
          bins.add(k);
          weights.add(v);
        }
      }
      return MelBin(
        bins.isNotEmpty ? bins.first : 0,
        Float64List.fromList(weights),
      );
    });
  }

  static final List<MelBin> _defaultBank = makeMelBank(sampleRate / 2.0 - 400.0);

  static final Float64List _cosTable = () {
    final list = Float64List(nfft ~/ 2);
    for (int k = 0; k < nfft ~/ 2; k++) {
      list[k] = math.cos((-2.0 * math.pi * k) / nfft);
    }
    return list;
  }();

  static final Float64List _sinTable = () {
    final list = Float64List(nfft ~/ 2);
    for (int k = 0; k < nfft ~/ 2; k++) {
      list[k] = math.sin((-2.0 * math.pi * k) / nfft);
    }
    return list;
  }();

  static final Uint16List _reversed = () {
    final list = Uint16List(nfft);
    for (int i = 0; i < nfft; i++) {
      int r = 0;
      for (int b = 1, x = i; b < nfft; b <<= 1, x >>= 1) {
        r = (r << 1) | (x & 1);
      }
      list[i] = r;
    }
    return list;
  }();

  static void _fft(Float64List re, Float64List im) {
    for (int i = 0; i < nfft; i++) {
      final j = _reversed[i];
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (int len = 2; len <= nfft; len <<= 1) {
      final half = len >> 1;
      final stride = nfft ~/ len;
      for (int i = 0; i < nfft; i += len) {
        for (int k = 0; k < half; k++) {
          final wr = _cosTable[k * stride];
          final wi = _sinTable[k * stride];
          final a = i + k;
          final b = a + half;
          final xr = re[b] * wr - im[b] * wi;
          final xi = re[b] * wi + im[b] * wr;
          re[b] = re[a] - xr;
          im[b] = im[a] - xi;
          re[a] += xr;
          im[a] += xi;
        }
      }
    }
  }

  final List<MelBin> bank;
  Float32List _pending = Float32List(0);
  final Float64List _re = Float64List(nfft);
  final Float64List _im = Float64List(nfft);

  TilawaFbank({double? highFrequency})
      : bank = highFrequency == null ? _defaultBank : makeMelBank(highFrequency);

  void reset() {
    _pending = Float32List(0);
  }

  /// Accepts 16 kHz float samples in [-1, 1]; returns every newly complete 80-dim frame.
  List<Float32List> push(Float32List samples) {
    final totalLen = _pending.length + samples.length;
    final buf = Float32List(totalLen);
    buf.setRange(0, _pending.length, _pending);
    buf.setRange(_pending.length, totalLen, samples);

    final out = <Float32List>[];
    int off = 0;
    for (; off + win <= buf.length; off += hop) {
      _re.fillRange(0, nfft, 0.0);
      _im.fillRange(0, nfft, 0.0);
      double mean = 0.0;
      for (int i = 0; i < win; i++) {
        mean += buf[off + i];
      }
      mean /= win;

      for (int i = win - 1; i >= 0; i--) {
        final x = buf[off + i] - mean;
        final prev = i > 0 ? buf[off + i - 1] - mean : x;
        _re[i] = (x - 0.97 * prev) * _povey[i];
      }

      _fft(_re, _im);

      final frame = Float32List(mels);
      for (int m = 0; m < mels; m++) {
        final bin = bank[m];
        final start = bin.start;
        final weights = bin.weights;
        double e = 0.0;
        final wLen = weights.length;
        for (int j = 0; j < wLen; j++) {
          final k = start + j;
          e += weights[j] * (_re[k] * _re[k] + _im[k] * _im[k]);
        }
        frame[m] = math.log(math.max(e, eps));
      }
      out.add(frame);
    }

    _pending = buf.sublist(off);
    return out;
  }
}
