import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';
import '../core/math_extensions.dart' as mathe;
import 'variant.dart';

enum Vector3Axis {
  x(0),
  y(1),
  z(2);

  final int value;
  const Vector3Axis(this.value);
  factory Vector3Axis.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }
}

class Vector3 extends BuiltinType {
  static const int _size = 12;
  static TypeInfo sTypeInfo = TypeInfo(
      Vector3, StringName.fromString('Vector3'),
      variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR3,
      size: _size,
      bindingToken: null);

  @override
  Pointer<Uint8> get nativePtr {
    _updateOpaque();
    return _opaque;
  }

  @override
  void constructCopy(GDExtensionTypePtr ptr) {
    gde.callBuiltinConstructor(_bindings.constructor_1!, ptr, [
      nativePtr.cast(),
    ]);
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  final Pointer<Uint8> _opaque = nullptr;
  final Float32List _data = Float32List(3);

  double get x => _data[0];
  set x(double value) => _data[0] = value;

  double get y => _data[1];
  set y(double value) => _data[1] = value;

  double get z => _data[2];
  set z(double value) => _data[2] = value;

  Vector3({double x = 0.0, double y = 0.0, double z = 0.0})
      : super.nonFinalized() {
    _data[0] = x;
    _data[1] = y;
    _data[2] = z;
  }

  Vector3.copy(Vector3 copy) : super.nonFinalized() {
    _data[0] = copy._data[0];
    _data[1] = copy._data[1];
    _data[2] = copy._data[2];
  }

  factory Vector3.up() {
    return Vector3(x: 0, y: 1, z: 0);
  }

  factory Vector3.forward() {
    return Vector3(x: 0, y: 0, z: -1);
  }

  Vector3.fromVariant(Variant variant)
      : this.fromVariantPtr(variant.nativePtr.cast());

  @internal
  Vector3.fromVariantPtr(GDExtensionVariantPtr variantPtr)
      : super.nonFinalized() {
    allocateOpaque(sTypeInfo.size, null);
    final c = getToTypeConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR3);
    if (c == null) return;

    c(_opaque.cast(), variantPtr);
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      byteData.setUint8(i, _opaque[i]);
    }
  }

  Vector3.copyPtr(Pointer<Void> pointer) : super.nonFinalized() {
    final bytePtr = pointer.cast<Uint8>();
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      byteData.setUint8(i, bytePtr[i]);
    }
  }

  // --- Godot Public Interface ---

  double get length {
    return math.sqrt(x * x + y * y + z * z);
  }

  double get lengthSquared {
    return x * x + y * y + z * z;
  }

  Vector3Axis minAxisIndex() {
    return x < y
        ? (x < z ? Vector3Axis.x : Vector3Axis.z)
        : (y < z ? Vector3Axis.y : Vector3Axis.z);
  }

  Vector3Axis maxAxisIndex() {
    return x < y
        ? (y < z ? Vector3Axis.z : Vector3Axis.y)
        : (x < z ? Vector3Axis.z : Vector3Axis.x);
  }

  double angleTo(Vector3 to) {
    return math.atan2(cross(to).length, dot(to));
  }

  double signedAngleTo(Vector3 to, Vector3 axis) {
    Vector3 crossTo = cross(to);
    double unsignedAngle = math.atan2(crossTo.length, dot(to));
    double sign = crossTo.dot(axis);
    return (sign < 0) ? -unsignedAngle : unsignedAngle;
  }

  Vector3 directionTo(Vector3 to) {
    final ret = Vector3(x: to.x - x, y: to.y - y, z: to.z - z);
    ret.normalize();
    return ret;
  }

  double distanceTo(Vector3 to) {
    return (to - this).length;
  }

  double distanceSquaredTo(Vector3 to) {
    return (to - this).lengthSquared;
  }

  Vector3 limitLength([double len = 1.0]) {
    final l = length;
    var v = Vector3.copy(this);
    if (l > 0 && len < 1) {
      v /= 1;
      v *= len;
    }

    return v;
  }

  void normalize() {
    final lengthsq = lengthSquared;
    if (lengthsq == 0) {
      x = y = z = 0;
    } else {
      final length = math.sqrt(lengthsq);
      x /= length;
      y /= length;
      z /= length;
    }
  }

  Vector3 get normalized => Vector3.copy(this)..normalize();

  bool get isNormalized => mathe.equalApprox(lengthSquared, 1);

  bool isEqualApprox(Vector3 to) {
    return mathe.equalApprox(x, to.x) &&
        mathe.equalApprox(y, to.y) &&
        mathe.equalApprox(z, to.z);
  }

  bool isZeroApprox() {
    return mathe.equalApprox(x, 0) &&
        mathe.equalApprox(y, 0) &&
        mathe.equalApprox(z, 0);
  }

  bool isFinite() {
    return x.isFinite && y.isFinite && z.isFinite;
  }

  Vector3 inverse() {
    return Vector3(x: 1.0 / x, y: 1.0 / y, z: 1.0 / z);
  }

  Vector3 clamp(Vector3 min, Vector3 max) {
    return Vector3(
      x: x.clamp(min.x, max.x),
      y: y.clamp(min.y, max.y),
      z: z.clamp(min.z, max.z),
    );
  }

  Vector3 snapped(Vector3 step) {
    return Vector3(
      x: x.snapped(step.x),
      y: y.snapped(step.y),
      z: z.snapped(step.z),
    );
  }

  Vector3 rotated(Vector3 axis, double angle) {
    final q = Quaternion.fromAxisAngle(axis, angle);
    final v = Vector3.copy(this)..applyQuaternion(q);
    return v;
  }

  void applyQuaternion(Quaternion arg) {
    //final argStorage = arg._qStorage;
    final v0 = _data[0];
    final v1 = _data[1];
    final v2 = _data[2];
    final qx = arg.x;
    final qy = arg.y;
    final qz = arg.z;
    final qw = arg.w;
    final ix = qw * v0 + qy * v2 - qz * v1;
    final iy = qw * v1 + qz * v0 - qx * v2;
    final iz = qw * v2 + qx * v1 - qy * v0;
    final iw = -qx * v0 - qy * v1 - qz * v2;
    _data[0] = ix * qw + iw * -qx + iy * -qz - iz * -qy;
    _data[1] = iy * qw + iw * -qy + iz * -qx - ix * -qz;
    _data[2] = iz * qw + iw * -qz + ix * -qy - iy * -qx;
  }

  Vector3 lerp(Vector3 to, double weight) {
    return Vector3(
      x: x + (weight * (to.x - x)),
      y: x + (weight * (to.y - y)),
      z: x + (weight * (to.z - z)),
    );
  }

  Vector3 slerp(Vector3 to, double weight) {
    // This method seems more complicated than it really is, since we write out
    // the internals of some methods for efficiency (mainly, checking length).
    final startLengthSq = lengthSquared;
    final endLengthSq = to.lengthSquared;
    if (startLengthSq == 0.0 || endLengthSq == 0.0) {
      // Zero length vectors have no angle, so the best we can do is either lerp or throw an error.
      return lerp(to, weight);
    }
    var axis = cross(to);
    final axisLengthSq = axis.lengthSquared;
    if (axisLengthSq == 0.0) {
      // Colinear vectors have no rotation axis or angle between them, so the best we can do is lerp.
      return lerp(to, weight);
    }
    axis /= math.sqrt(axisLengthSq);
    final startLength = math.sqrt(startLengthSq);
    final resultLength =
        mathe.lerp(startLength, math.sqrt(endLengthSq), weight);
    final angle = angleTo(to);
    return rotated(axis, angle * weight) * (resultLength / startLength);
  }

  Vector3 cubicInterpolate(
      Vector3 b, Vector3 preA, Vector3 postB, double weight) {
    return Vector3(
      x: mathe.cubicInterpolate(x, b.x, preA.x, postB.x, weight),
      y: mathe.cubicInterpolate(y, b.y, preA.y, postB.y, weight),
      z: mathe.cubicInterpolate(z, b.z, preA.z, postB.z, weight),
    );
  }

  Vector3 cubicInterpolateInTime(
    Vector3 b,
    Vector3 preA,
    Vector3 postB,
    double weight,
    double bT,
    double preAT,
    double postBT,
  ) {
    return Vector3(
      x: mathe.cubicInterpolateInTime(
          x, b.x, preA.x, postB.x, weight, bT, preAT, postBT),
      y: mathe.cubicInterpolateInTime(
          y, b.y, preA.y, postB.y, weight, bT, preAT, postBT),
      z: mathe.cubicInterpolateInTime(
          z, b.z, preA.z, postB.z, weight, bT, preAT, postBT),
    );
  }

  Vector3 bezierInterpolate(
    Vector3 control1,
    Vector3 control2,
    Vector3 end,
    double t,
  ) {
    return Vector3(
      x: mathe.bezierInterpolate(x, control1.x, control2.x, end.x, t),
      y: mathe.bezierInterpolate(y, control1.y, control2.y, end.y, t),
      z: mathe.bezierInterpolate(z, control1.z, control2.z, end.z, t),
    );
  }

  Vector3 bezierDerivative(
    Vector3 control1,
    Vector3 control2,
    Vector3 end,
    double t,
  ) {
    return Vector3(
      x: mathe.bezierDerivative(x, control1.x, control2.x, end.x, t),
      y: mathe.bezierDerivative(y, control1.y, control2.y, end.y, t),
      z: mathe.bezierDerivative(z, control1.z, control2.z, end.z, t),
    );
  }

  Vector3 moveToward(Vector3 to, double delta) {
    final v = Vector3.copy(this);
    final vd = to - v;
    final len = vd.length;
    return len <= delta || len < 0.001 ? to : v + vd / len * delta;
  }

  Vector3 cross(Vector3 other) {
    return Vector3(
      x: (y * other.z) - (z * other.y),
      y: (z * other.x) - (x * other.z),
      z: (x * other.y) - (y * other.x),
    );
  }

  double dot(Vector3 other) {
    return x * other.x + y * other.y + z * other.z;
  }

  Vector3 abs() {
    return Vector3(x: x.abs(), y: y.abs(), z: z.abs());
  }

  Vector3 floor() {
    return Vector3(
      x: x.floor().toDouble(),
      y: y.floor().toDouble(),
      z: z.floor().toDouble(),
    );
  }

  Vector3 ceil() {
    return Vector3(
      x: x.ceil().toDouble(),
      y: y.ceil().toDouble(),
      z: z.ceil().toDouble(),
    );
  }

  Vector3 round() {
    return Vector3(
      x: x.round().toDouble(),
      y: y.round().toDouble(),
      z: z.round().toDouble(),
    );
  }

  Vector3 posmod(double mod) {
    return Vector3(
      x: mathe.fposmod(x, mod),
      y: mathe.fposmod(y, mod),
      z: mathe.fposmod(z, mod),
    );
  }

  Vector3 posmodv(Vector3 modv) {
    return Vector3(
      x: mathe.fposmod(x, modv.x),
      y: mathe.fposmod(y, modv.y),
      z: mathe.fposmod(z, modv.z),
    );
  }

  Vector3 project(Vector3 to) {
    return to * (dot(to) / to.lengthSquared);
  }

  Vector3 slide(Vector3 n) {
    return this - n * dot(n);
  }

  Vector3 bounce(Vector3 n) {
    return -reflect(n);
  }

  Vector3 reflect(Vector3 n) {
    return n * 2.0 * dot(n) - this;
  }

  Vector3 sign() {
    return Vector3(x: x.sign, y: y.sign, z: z.sign);
  }

  Vector2 octahedronEncode() {
    var n = Vector3.copy(this);
    n /= n.x.abs() + n.y.abs() + n.z.abs();
    var o = Vector2();
    if (n.z >= 0.0) {
      o.x = n.x;
      o.y = n.y;
    } else {
      o.x = (1.0 - n.y.abs()) * (n.x >= 0.0 ? 1.0 : -1.0);
      o.y = (1.0 - n.x.abs()) * (n.y >= 0.0 ? 1.0 : -1.0);
    }
    o.x = o.x * 0.5 + 0.5;
    o.y = o.y * 0.5 + 0.5;
    return o;
  }

  static Vector3 octahedronDecode(Vector2 uv) {
    Vector2 f = Vector2.fromXY(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0);
    Vector3 n = Vector3(x: f.x, y: f.y, z: 1.0 - f.x.abs() - f.y.abs());
    double t = (-n.z).clamp(0.0, 1.0);
    n.x += n.x >= 0 ? -t : t;
    n.y += n.y >= 0 ? -t : t;
    return n.normalized;
  }

  void add(Vector3 other) {
    x += other.x;
    y += other.y;
    z += other.z;
  }

  void subtract(Vector3 other) {
    x -= other.x;
    y -= other.y;
    z -= other.z;
  }

  void scale(num scale) {
    x *= scale;
    y *= scale;
    z *= scale;
  }

  void negate() {
    x = -x;
    y = -y;
    z = -z;
  }

  // --- Operators ---
  Vector3 operator -() => Vector3.copy(this)..negate();

  Vector3 operator +(Vector3 other) => Vector3.copy(this)..add(other);

  Vector3 operator -(Vector3 other) => Vector3.copy(this)..subtract(other);

  Vector3 operator *(num scale) => Vector3.copy(this)..scale(scale);

  Vector3 operator /(num scale) => Vector3.copy(this)..scale(1.0 / scale);

  void updateFromOpaque() {
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      byteData.setUint8(i, _opaque[i]);
    }
  }

  void _updateOpaque() {
    if (_opaque == nullptr) {
      allocateOpaque(sTypeInfo.size, null);
    }
    final byteData = _data.buffer.asByteData();
    for (int i = 0; i < byteData.lengthInBytes; ++i) {
      _opaque[i] = byteData.getUint8(i);
    }
  }

  static final _Vector3Bindings _bindings = _Vector3Bindings();
  static void initBindings() {
    _bindings.constructor_0 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR3, 0);
    _bindings.constructor_1 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR3, 1);
  }
}

class _Vector3Bindings {
  GDExtensionPtrConstructor? constructor_0;
  GDExtensionPtrConstructor? constructor_1;
}
