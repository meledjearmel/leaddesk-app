import 'dart:ui';

/// Statistiques de fluidité calculées à partir des [FrameTiming] du moteur.
class FrameStats {
  FrameStats({this.budgetMs = 1000 / 60});

  /// Budget d'une image à 60 images par seconde.
  final double budgetMs;

  final List<double> _buildMs = <double>[];
  final List<double> _rasterMs = <double>[];
  final List<double> _totalMs = <double>[];

  int get frames => _totalMs.length;

  void add(FrameTiming timing) {
    addDurations(build: timing.buildDuration, raster: timing.rasterDuration);
  }

  void addDurations({required Duration build, required Duration raster}) {
    final buildMs = build.inMicroseconds / 1000;
    final rasterMs = raster.inMicroseconds / 1000;
    _buildMs.add(buildMs);
    _rasterMs.add(rasterMs);
    _totalMs.add(buildMs + rasterMs);
  }

  void clear() {
    _buildMs.clear();
    _rasterMs.clear();
    _totalMs.clear();
  }

  static double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = List<double>.of(values)..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }

  /// Part des images dont le travail (construction + rendu) dépasse le budget.
  double get slowFrameRatio {
    if (_totalMs.isEmpty) {
      return 0;
    }
    return _totalMs.where((ms) => ms > budgetMs).length / _totalMs.length;
  }

  Map<String, Object> summary({required double elapsedSeconds}) {
    double round(double value) => (value * 100).roundToDouble() / 100;
    return <String, Object>{
      'frames': frames,
      'elapsed_seconds': round(elapsedSeconds),
      'average_fps': round(elapsedSeconds > 0 ? frames / elapsedSeconds : 0),
      'build_ms_average': round(_average(_buildMs)),
      'build_ms_p99': round(_percentile(_buildMs, 0.99)),
      'raster_ms_average': round(_average(_rasterMs)),
      'raster_ms_p99': round(_percentile(_rasterMs, 0.99)),
      'total_ms_average': round(_average(_totalMs)),
      'total_ms_p99': round(_percentile(_totalMs, 0.99)),
      'total_ms_worst': round(_percentile(_totalMs, 1)),
      'slow_frame_percent': round(slowFrameRatio * 100),
    };
  }
}
