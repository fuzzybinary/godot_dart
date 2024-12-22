import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';
import '../core/math_extensions.dart' as mathe;
import 'variant.dart';

enum Vector2Axis {
  x(0),
  y(1);

  final int value;
  const Vector2Axis(this.value);
  factory Vector2Axis.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }
}

class Vector2 extends BuiltinType {
  static const int _size = 8;
  static TypeInfo sTypeInfo = TypeInfo(
    Vector2,
    StringName.fromString('Vector2'),
    StringName(),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR2,
    size: _size,
  );

  @override
  Pointer<Uint8> get nativePtr {
    _updateOpaque();
    return nativeDataPtr;
  }

  @override
  void constructCopy(GDExtensionTypePtr ptr) {
    gde.callBuiltinConstructor(_bindings.constructor_1!, ptr, [
      nativePtr.cast(),
    ]);
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  final Float32List _data = Float32List(2);

  double get x => _data[0];
  set x(double value) => _data[0] = value;

  double get y => _data[1];
  set y(double value) => _data[1] = value;

  Vector2({double x = 0.0, double y = 0.0}) : super.nonFinalized() {
    _data[0] = x;
    _data[1] = y;
  }

  Vector2.copy(Vector2 copy) : super.nonFinalized() {
    _data[0] = copy._data[0];
    _data[1] = copy._data[1];
  }

  Vector2.fromXY(double x, double y) : super.nonFinalized() {
    _data[0] = x;
    _data[1] = y;
  }

  factory Vector2.zero() {
    return Vector2(x: 0, y: 0);
  }

  factory Vector2.left() {
    return Vector2(x: -1, y: 0);
  }

  factory Vector2.right() {
    return Vector2(x: 1, y: 0);
  }

  factory Vector2.up() {
    return Vector2(x: 0, y: -1);
  }

  factory Vector2.down() {
    return Vector2(x: 0, y: 1);
  }

  Vector2.fromVariant(Variant variant)
      : this.fromVariantPtr(variant.nativePtr.cast());

  @internal
  Vector2.fromVariantPtr(GDExtensionVariantPtr variantPtr)
      : super.nonFinalized() {
    allocateOpaque(sTypeInfo.size, null);
    final c = getToTypeConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR2);
    if (c == null) return;

    c(nativeDataPtr.cast(), variantPtr);
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      byteData.setUint8(i, nativeDataPtr[i]);
    }
  }

  Vector2.copyPtr(Pointer<Void> pointer) : super.nonFinalized() {
    final bytePtr = pointer.cast<Uint8>();
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      byteData.setUint8(i, bytePtr[i]);
    }
  }

  // --- Godot Public Interface ---
  double angle() {
    return math.atan2(y, x);
  }

  Vector2 fromAngle(double angle) {
    return Vector2(x: math.cos(angle), y: math.sin(angle));
  }

  double get length {
    return math.sqrt(x * x + y * y);
  }

  double get lengthSquared {
    return x * x + y * y;
  }

  Vector2 min(Vector2 vector2) {
    return Vector2(x: math.min(x, vector2.x), y: math.min(y, vector2.y));
  }

  Vector2 max(Vector2 vector2) {
    return Vector2(x: math.max(x, vector2.x), y: math.max(y, vector2.y));
  }

  Vector2 abs() {
    return Vector2(x: x.abs(), y: y.abs());
  }

  void normalize() {
    double l = lengthSquared;
    if (l != 0) {
      l = math.sqrt(l);
      x /= l;
      y /= l;
    }
  }

  Vector2 normalized() => Vector2.copy(this)..normalize();

  bool get isNormalized => mathe.equalApprox(lengthSquared, 1);

  double distanceTo(Vector2 vector2) {
    return math.sqrt(
        (x - vector2.x) * (x - vector2.x) + (y - vector2.y) * (y - vector2.y));
  }

  double distanceSquaredTo(Vector2 vector2) {
    return (x - vector2.x) * (x - vector2.x) +
        (y - vector2.y) * (y - vector2.y);
  }

  double angleTo(Vector2 vector2) {
    return math.atan2(cross(vector2), dot(vector2));
  }

  double angleToPoint(Vector2 vector2) {
    return (vector2 - this).angle();
  }

  double dot(Vector2 other) {
    return x * other.x + y * other.y;
  }

  double cross(Vector2 other) {
    return x * other.y - y * other.x;
  }

  Vector2 sign() {
    return Vector2(x: x.sign, y: y.sign);
  }

  Vector2 floor() {
    return Vector2(x: x.floorToDouble(), y: y.floorToDouble());
  }

  Vector2 ceil() {
    return Vector2(x: x.ceilToDouble(), y: y.ceilToDouble());
  }

  Vector2 round() {
    return Vector2(x: x.roundToDouble(), y: y.roundToDouble());
  }

  Vector2 rotated(double by) {
    final sine = math.sin(by);
    final cosi = math.cos(by);
    return Vector2(x: x * cosi - y * sine, y: x * sine + y * cosi);
  }

  Vector2 orthogonal() {
    return Vector2(x: y, y: -x);
  }

  Vector2 posmod(double mod) {
    return Vector2(x: mathe.fposmod(x, mod), y: mathe.fposmod(y, mod));
  }

  Vector2 posmodv(Vector2 modv) {
    return Vector2(x: mathe.fposmod(x, modv.x), y: mathe.fposmod(y, modv.y));
  }

  Vector2 project(Vector2 to) {
    return to * (dot(to) / to.lengthSquared);
  }

  Vector2 planeProject(double d, Vector2 vec) {
    return vec - this * (dot(vec) - d);
  }

  Vector2 clamp(Vector2 min, Vector2 max) {
    return Vector2(x: x.clamp(min.x, max.x), y: y.clamp(min.y, max.y));
  }

  Vector2 lerp(Vector2 to, double weight) {
    Vector2 res = Vector2.copy(this);

    res.x += (weight * (to.x - x));
    res.y += (weight * (to.y - y));

    return res;
  }

  Vector2 slerp(Vector2 to, double weight) {
    final startLengthSq = lengthSquared;
    final endLengthSq = to.lengthSquared;
    if (startLengthSq == 0.0 || endLengthSq == 0.0) {
      // Zero length vectors have no angle, so the best we can do is either lerp or throw an error.
      return lerp(to, weight);
    }
    final startLength = math.sqrt(startLengthSq);
    final resultLength =
        mathe.lerp(startLength, math.sqrt(endLengthSq), weight);
    final angle = angleTo(to);
    return rotated(angle * weight) * (resultLength / startLength);
  }

  Vector2 cubicInterpolate(
    Vector2 b,
    Vector2 preA,
    Vector2 postB,
    double weight,
  ) {
    Vector2 res = Vector2.copy(this);
    res.x = mathe.cubicInterpolate(res.x, b.x, preA.x, postB.x, weight);
    res.y = mathe.cubicInterpolate(res.y, b.y, preA.y, postB.y, weight);
    return res;
  }

  Vector2 cubicInterpolateInTime(Vector2 b, Vector2 preA, Vector2 postB,
      double pWeight, double bT, double preAT, double pPostBT) {
    Vector2 res = Vector2.copy(this);
    res.x = mathe.cubicInterpolateInTime(
        res.x, b.x, preA.x, postB.x, pWeight, bT, preAT, pPostBT);
    res.y = mathe.cubicInterpolateInTime(
        res.y, b.y, preA.y, postB.y, pWeight, bT, preAT, pPostBT);
    return res;
  }

  Vector2 bezierInterpolate(
      Vector2 control1, Vector2 control2, Vector2 end, double t) {
    Vector2 res = Vector2.copy(this);

    /* Formula from Wikipedia article on Bezier curves. */
    double omt = (1.0 - t);
    double omt2 = omt * omt;
    double omt3 = omt2 * omt;
    double t2 = t * t;
    double t3 = t2 * t;

    return res * omt3 +
        control1 * omt2 * t * 3.0 +
        control2 * omt * t2 * 3.0 +
        end * t3;
  }

  double get aspect => x / y;

  Vector2 snapped(Vector2 step) {
    return Vector2(x: x.snapped(step.x), y: y.snapped(step.y));
  }

  Vector2 limitLength(double len) {
    double l = length;
    Vector2 v = this;
    if (l > 0 && len < l) {
      v /= l;
      v *= len;
    }

    return v;
  }

  Vector2 moveToward(Vector2 to, double delta) {
    Vector2 v = Vector2.copy(this);
    Vector2 vd = to - v;
    double len = vd.length;
    return len <= delta || len < 0.001 ? to : v + vd / len * delta;
  }

  Vector2 slide(Vector2 normal) {
    return this - normal * dot(normal);
  }

  Vector2 bounce(Vector2 normal) {
    return -reflect(normal);
  }

  Vector2 reflect(Vector2 normal) {
    return normal * 2.0 * dot(normal) - this;
  }

  bool isEqualApprox(Vector2 v) {
    return mathe.equalApprox(x, v.x) && mathe.equalApprox(y, v.y);
  }

  bool isZeroApprox() {
    return mathe.equalApprox(x, 0) && mathe.equalApprox(y, 0);
  }

  bool isFinite() {
    return x.isFinite && y.isFinite;
  }

  Vector2 inverse() {
    return Vector2(x: 1.0 / x, y: 1.0 / y);
  }

  void add(Vector2 other) {
    x += other.x;
    y += other.y;
  }

  void subtract(Vector2 other) {
    x -= other.x;
    y -= other.y;
  }

  void scale(num scale) {
    x *= scale;
    y *= scale;
  }

  void negate() {
    x = -x;
    y = -y;
  }

  Vector2 operator -() => Vector2.copy(this)..negate();

  Vector2 operator +(Vector2 other) => Vector2.copy(this)..add(other);

  Vector2 operator -(Vector2 other) => Vector2.copy(this)..subtract(other);

  Vector2 operator *(num scale) => Vector2.copy(this)..scale(scale);

  Vector2 operator /(num scale) => Vector2.copy(this)..scale(1.0 / scale);

  void updateFromOpaque() {
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      byteData.setUint8(i, nativeDataPtr[i]);
    }
  }

  void _updateOpaque() {
    if (nativeDataPtr == nullptr) {
      allocateOpaque(sTypeInfo.size, null);
    }
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      nativeDataPtr[i] = byteData.getUint8(i);
    }
  }

  static final _Vector2Bindings _bindings = _Vector2Bindings();
  static void initBindings() {
    _bindings.constructor_0 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR2, 0);
    _bindings.constructor_1 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR2, 1);
  }
}

class _Vector2Bindings {
  GDExtensionPtrConstructor? constructor_0;
  GDExtensionPtrConstructor? constructor_1;
}
