// These are mostly taken from Godot's Math namespace in service of implementing
// math variants in Dart.

bool equalApprox(double a, double b, [double epsilon = 0.001]) {
  if (a == b) return true;
  return (a - b).abs() < epsilon;
}

double lerp(double minv, double maxv, double t) {
  return minv + t * (maxv - minv);
}

double cubicInterpolate(
  double from,
  double to,
  double pre,
  double post,
  double weight,
) {
  return 0.5 *
      ((from * 2.0) +
          (-pre + to) * weight +
          (2.0 * pre - 5.0 * from + 4.0 * to - post) * (weight * weight) +
          (-pre + 3.0 * from - 3.0 * to + post) * (weight * weight * weight));
}

double cubicInterpolateInTime(
  double from,
  double to,
  double pre,
  double post,
  double weight,
  double toT,
  double preT,
  double postT,
) {
  /* Barry-Goldman method */
  final t = lerp(0.0, toT, weight);
  final a1 = lerp(pre, from, preT == 0 ? 0.0 : (t - preT) / -preT);
  final a2 = lerp(from, to, toT == 0 ? 0.5 : t / toT);
  final a3 = lerp(to, post, postT - toT == 0 ? 1.0 : (t - toT) / (postT - toT));
  final b1 = lerp(a1, a2, toT - preT == 0 ? 0.0 : (t - preT) / (toT - preT));
  final b2 = lerp(a2, a3, postT == 0 ? 1.0 : t / postT);
  return lerp(b1, b2, toT == 0 ? 0.5 : t / toT);
}

double bezierInterpolate(
    double start, double control1, double control2, double end, double t) {
  /* Formula from Wikipedia article on Bezier curves. */
  double omt = (1.0 - t);
  double omt2 = omt * omt;
  double omt3 = omt2 * omt;
  double t2 = t * t;
  double t3 = t2 * t;

  return start * omt3 +
      control1 * omt2 * t * 3.0 +
      control2 * omt * t2 * 3.0 +
      end * t3;
}

double bezierDerivative(
    double start, double control1, double control2, double end, double t) {
  /* Formula from Wikipedia article on Bezier curves. */
  double omt = (1.0 - t);
  double omt2 = omt * omt;
  double t2 = t * t;

  double d = (control1 - start) * 3.0 * omt2 +
      (control2 - control1) * 6.0 * omt * t +
      (end - control2) * 3.0 * t2;
  return d;
}

double fmod(double x, double y) {
  return x - (x / y).truncateToDouble() * y;
}

double fposmod(double x, double y) {
  double value = fmod(x, y);
  if ((value < 0 && y > 0) || (value > 0 && y < 0)) {
    value += y;
  }
  value += 0.0;
  return value;
}

extension GodotMathUtils on double {
  double snapped(double step) {
    if (step == 0) return this;
    return (this / step + 0.5).floor() * step;
  }
}
