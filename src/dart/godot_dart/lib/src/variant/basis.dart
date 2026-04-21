import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';
import '../core/math_extensions.dart' as mathe;
import '../core/math_extensions.dart';
import 'variant.dart';

const double _sqrt12 = 0.7071067811865475244008443621048490;
const double _cmpEpsilon = 0.00001;
const double _cmpEpsilon2 = (_cmpEpsilon * _cmpEpsilon);

class Basis extends CopyiedBuiltinType {
  static const int _size = 36;
  static final sTypeInfo = BuiltinTypeInfo<Basis>(
    className: StringName.fromString('Basis'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BASIS,
    size: _size,
    constructObjectDefault: () => Basis(),
    constructCopy: (ptr) => Basis.copyPtr(ptr),
  );

  @override
  BuiltinTypeInfo<Basis> get typeInfo => sTypeInfo;

  final List<Vector3> _rows =
      List.generate(3, (_) => Vector3(), growable: false);

  Basis() {
    _rows[0][0] = 1.0;
    _rows[1][1] = 1.0;
    _rows[2][2] = 1.0;
  }

  Basis.copy(Basis copy) {
    _rows[0] = Vector3.copy(copy._rows[0]);
    _rows[1] = Vector3.copy(copy._rows[1]);
    _rows[2] = Vector3.copy(copy._rows[2]);
  }

  Basis.fromAxisAngle(Vector3 axis, double angle) {
    setAxisAngle(axis, angle);
  }

  Basis.fromEuler(Vector3 euler, {EulerOrder order = EulerOrder.yxz}) {
    setEuler(euler, order: order);
  }

  Basis.fromQuaternion(Quaternion quaternion) {
    setQuaternion(quaternion);
  }

  Basis.fromScale(Vector3 scale) {
    set(scale.x, 0, 0, 0, scale.y, 0, 0, 0, scale.z);
  }

  Basis.lookingAt(Vector3 target, {Vector3? up}) {
    up ??= Vector3.up();

    Vector3 vZ = -target.normalized;
    Vector3 vX = up.cross(vZ);
    vX.normalize();
    Vector3 vY = vZ.cross(vX);

    setColumns(vX, vY, vZ);
  }

  Basis.copyPtr(Pointer<Void> pointer) {
    copyFrom(pointer.cast());
  }

  Basis.fromVariant(Variant variant)
      : this.fromVariantPtr(variant.nativePtr.cast());

  @internal
  Basis.fromVariantPtr(GDExtensionVariantPtr variantPtr) {
    final c = getToTypeConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BASIS);
    if (c == null) return;

    using((arena) {
      final nativeMem = arena.allocate<Uint8>(_size);

      c(nativeMem.cast(), variantPtr);
      copyFrom(nativeMem);
    });
  }

  void invert() {
    final co = [
      _cofac(1, 1, 2, 2),
      _cofac(1, 2, 2, 0),
      _cofac(1, 0, 2, 1),
    ];
    final det = _rows[0][0] * co[0] + _rows[0][1] * co[1] + _rows[0][2] * co[2];
    final s = 1.0 / det;
    set(
      co[0] * s,
      _cofac(0, 2, 2, 1) * s,
      _cofac(0, 1, 1, 2) * s,
      co[1] * s,
      _cofac(0, 0, 2, 2) * s,
      _cofac(0, 2, 1, 0) * s,
      co[2] * s,
      _cofac(0, 1, 2, 0) * s,
      _cofac(0, 0, 1, 1) * s,
    );
  }

  Basis inverse() {
    final inv = Basis.copy(this);
    inv.invert();
    return inv;
  }

  void transpose() {
    final temp = [_rows[0][1], _rows[0][2], _rows[1][2]];
    _rows[0][1] = _rows[1][0];
    _rows[0][2] = _rows[2][0];
    _rows[1][2] = _rows[2][1];
    _rows[1][0] = temp[0];
    _rows[2][0] = temp[1];
    _rows[2][1] = temp[2];
  }

  Basis transposed() {
    final tr = Basis.copy(this);
    tr.transpose();
    return tr;
  }

  double determinant() {
    return _rows[0][0] *
            (_rows[1][1] * _rows[2][2] - _rows[2][1] * _rows[1][2]) -
        _rows[1][0] * (_rows[0][1] * _rows[2][2] - _rows[2][1] * _rows[0][2]) +
        _rows[2][0] * (_rows[0][1] * _rows[1][2] - _rows[1][1] * _rows[0][2]);
  }

  void fromZ(Vector3 z) {
    if (z.z.abs() > _sqrt12) {
      // choose p in y-z plane
      final a = z.y * z.y + z.z * z.z;
      final k = 1.0 / math.sqrt(a);
      _rows[0].set(0, -z.z * k, z.y * k);
      _rows[1].set(a * k, -z.x * _rows[0][2], z.x * _rows[0][1]);
    } else {
      // choose p in x-y plane
      final a = z.x * z.x + z.y * z.y;
      final k = 1.0 / math.sqrt(a);
      _rows[0].set(z.y * k, z.x * k, 0);
      _rows[1].set(-z.z * _rows[0][2], z.z * _rows[0][0], a * k);
    }
    _rows[2].set(z.x, z.y, z.z);
  }

  void rotate(Vector3 axis, double angle) {
    _copy(rotated(axis, angle));
  }

  Basis rotated(Vector3 axis, double angle) {
    return Basis.fromAxisAngle(axis, angle) * this;
  }

  void rotateLocal(Vector3 axis, double angle) {
    _copy(rotatedLocal(axis, angle));
  }

  Basis rotatedLocal(Vector3 axis, double angle) {
    return this * Basis.fromAxisAngle(axis, angle);
  }

  void rotateEuler(Vector3 euler, {EulerOrder order = EulerOrder.xyz}) {
    _copy(rotatedEuler(euler, order: order));
  }

  Basis rotatedEuler(Vector3 euler, {EulerOrder order = EulerOrder.xyz}) {
    return Basis.fromEuler(euler, order: order) * this;
  }

  void rotateQuaternion(Quaternion quaternion) {
    _copy(rotatedQuaternion(quaternion));
  }

  Basis rotatedQuaternion(Quaternion quaternion) {
    return Basis.fromQuaternion(quaternion) * this;
  }

  Vector3 getEulerNormalized({EulerOrder order = EulerOrder.yxz}) {
    // Assumes that the matrix can be decomposed into a proper rotation and scaling matrix as M = R.S,
    // and returns the Euler angles corresponding to the rotation part, complementing get_scale().
    // See the comment in get_scale() for further information.
    Basis m = orthonormalized();
    double det = m.determinant();
    if (det < 0) {
      // Ensure that the determinant is 1, such that result is a proper rotation matrix which can be represented by Euler angles.
      m.scale(Vector3(x: -1, y: -1, z: -1));
    }

    return m.getEuler(order: order);
  }

  ({Vector3 axis, double angle}) getRotationAxisAngle() {
    // Assumes that the matrix can be decomposed into a proper rotation and scaling matrix as M = R.S,
    // and returns the Euler angles corresponding to the rotation part, complementing get_scale().
    // See the comment in get_scale() for further information.
    Basis m = orthonormalized();
    double det = m.determinant();
    if (det < 0) {
      // Ensure that the determinant is 1, such that result is a proper rotation matrix which can be represented by Euler angles.
      m.scale(Vector3(x: -1, y: -1, z: -1));
    }

    return m.getAxisAngle();
  }

  ({Vector3 axis, double angle}) getRotationAxisAngleLocal() {
    // Assumes that the matrix can be decomposed into a proper rotation and scaling matrix as M = R.S,
    // and returns the Euler angles corresponding to the rotation part, complementing get_scale().
    // See the comment in get_scale() for further information.
    Basis m = transposed();
    m.orthonormalize();
    double det = m.determinant();
    if (det < 0) {
      // Ensure that the determinant is 1, such that result is a proper rotation matrix which can be represented by Euler angles.
      m.scale(Vector3(x: -1, y: -1, z: -1));
    }

    final ret = m.getAxisAngle();
    return (axis: ret.axis, angle: -ret.angle);
  }

  Quaternion getRotationQuaternion() {
    // Assumes that the matrix can be decomposed into a proper rotation and scaling matrix as M = R.S,
    // and returns the Euler angles corresponding to the rotation part, complementing get_scale().
    // See the comment in get_scale() for further information.
    Basis m = orthonormalized();
    double det = m.determinant();
    if (det < 0) {
      // Ensure that the determinant is 1, such that result is a proper rotation matrix which can be represented by Euler angles.
      m.scale(Vector3(x: -1, y: -1, z: -1));
    }

    return m.getQuaternion();
  }

  void rotateToAlign(Vector3 startDirection, Vector3 endDirection) {
    // Takes two vectors and rotates the basis from the first vector to the second vector.
    // Adopted from: https://gist.github.com/kevinmoran/b45980723e53edeb8a5a43c49f134724
    final Vector3 axis = startDirection.cross(endDirection).normalized;
    if (axis.lengthSquared != 0) {
      double dot = startDirection.dot(endDirection);
      dot = dot.clamp(-1.0, 1.0);
      double angleRads = math.acos(dot);
      setAxisAngle(axis, angleRads);
    }
  }

  void orthonormalize() {
    // Gram-Schmidt Process

    Vector3 x = getColumn(0);
    Vector3 y = getColumn(1);
    Vector3 z = getColumn(2);

    x.normalize();
    y = (y - x * (x.dot(y)));
    y.normalize();
    z = (z - x * (x.dot(z)) - y * (y.dot(z)));
    z.normalize();

    setColumn(0, x);
    setColumn(1, y);
    setColumn(2, z);
  }

  Basis orthonormalized() {
    Basis ret = Basis.copy(this)..orthonormalize();
    return ret;
  }

  void orthogonalize() {
    Vector3 scl = getScale();
    orthonormalize();
    scaleLocal(scl);
  }

  Basis orthogonalized() {
    Basis c = Basis.copy(this);
    c.orthogonalize();
    return c;
  }

  Basis diagonalize() {
    const int iteMax = 1024;

    double offMatrixNorm2 = _rows[0][1] * _rows[0][1] +
        _rows[0][2] * _rows[0][2] +
        _rows[1][2] * _rows[1][2];

    int ite = 0;
    Basis accRot = Basis();
    while (offMatrixNorm2 > _cmpEpsilon2 && ite++ < iteMax) {
      double el01_2 = _rows[0][1] * _rows[0][1];
      double el02_2 = _rows[0][2] * _rows[0][2];
      double el12_2 = _rows[1][2] * _rows[1][2];
      // Find the pivot element
      int i, j;
      if (el01_2 > el02_2) {
        if (el12_2 > el01_2) {
          i = 1;
          j = 2;
        } else {
          i = 0;
          j = 1;
        }
      } else {
        if (el12_2 > el02_2) {
          i = 1;
          j = 2;
        } else {
          i = 0;
          j = 2;
        }
      }

      // Compute the rotation angle
      double angle;
      if (_rows[j][j].isEqualApprox(_rows[i][i])) {
        angle = math.pi / 4;
      } else {
        angle = 0.5 * math.atan(2 * _rows[i][j] / (_rows[j][j] - _rows[i][i]));
      }

      // Compute the rotation matrix
      Basis rot = Basis();
      rot._rows[i][i] = rot._rows[j][j] = math.cos(angle);
      rot._rows[i][j] = -(rot._rows[j][i] = math.sin(angle));

      // Update the off matrix norm
      offMatrixNorm2 -= _rows[i][j] * _rows[i][j];

      // Apply the rotation
      _copy(rot * this * rot.transposed());
      accRot = rot * accRot;
    }

    return accRot;
  }

  Basis lerp(Basis to, double weight) {
    Basis b = Basis();
    b._rows[0] = _rows[0].lerp(to._rows[0], weight);
    b._rows[1] = _rows[1].lerp(to._rows[1], weight);
    b._rows[2] = _rows[2].lerp(to._rows[2], weight);

    return b;
  }

  Basis slerp(Basis to, double weight) {
    Quaternion from = Quaternion.fromBasis(this);
    Quaternion qTo = Quaternion.fromBasis(to);

    Basis b = Basis.fromQuaternion(from.slerp(qTo, weight));
    b._rows[0] *= mathe.lerp(_rows[0].length, to._rows[0].length, weight);
    b._rows[1] *= mathe.lerp(_rows[1].length, to._rows[1].length, weight);
    b._rows[2] *= mathe.lerp(_rows[2].length, to._rows[2].length, weight);

    return b;
  }

  void scale(Vector3 scale) {
    _rows[0][0] *= scale.x;
    _rows[0][1] *= scale.x;
    _rows[0][2] *= scale.x;
    _rows[1][0] *= scale.y;
    _rows[1][1] *= scale.y;
    _rows[1][2] *= scale.y;
    _rows[2][0] *= scale.z;
    _rows[2][1] *= scale.z;
    _rows[2][2] *= scale.z;
  }

  Basis scaled(Vector3 scale) {
    final ret = Basis.copy(this)..scale(scale);
    return ret;
  }

  void scaleLocal(Vector3 scale) {
    _copy(scaledLocal(scale));
  }

  Basis scaledLocal(Vector3 scale) {
    return this * Basis.fromScale(scale);
  }

  void scaleOrthogonal(Vector3 scale) {
    _copy(scaledOrthogonal(scale));
  }

  Basis scaledOrthogonal(Vector3 scale) {
    Basis m = Basis.copy(this);
    Vector3 s = Vector3(x: -1, y: -1, z: -1) + scale;
    Vector3 dots = Vector3();
    Basis b = Basis();
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        dots[j] += s[i] * m.getColumn(i).normalized.dot(b.getColumn(j)).abs();
      }
    }
    m.scaleLocal(Vector3(x: 1, y: 1, z: 1) + dots);
    return m;
  }

  void makeScaleUniform() {
    double l = (_rows[0].length + _rows[1].length + _rows[2].length) / 3.0;
    for (int i = 0; i < 3; i++) {
      _rows[i].normalize();
      _rows[i] *= l;
    }
  }

  double getUniformScale() {
    return (_rows[0].length + _rows[1].length + _rows[2].length) / 3.0;
  }

  Vector3 getScale() {
    // See https://github.com/godotengine/godot/blob/220b0b2f74d8e089481b140c42a42992a76dd6fc/core/math/basis.cpp#L301
    // for a description of how this needs to be fixed. For now, do what the engine does.
    double detSign = determinant().sign;
    return getScaleAbs() * detSign;
  }

  Vector3 getScaleAbs() {
    return Vector3(
        x: Vector3(x: _rows[0][0], y: _rows[1][0], z: _rows[2][0]).length,
        y: Vector3(x: _rows[0][1], y: _rows[1][1], z: _rows[2][1]).length,
        z: Vector3(x: _rows[0][2], y: _rows[1][2], z: _rows[2][2]).length);
  }

  Vector3 getScaleLocal() {
    double detSign = determinant().sign;
    return Vector3(x: _rows[0].length, y: _rows[1].length, z: _rows[2].length) *
        detSign;
  }

  void set(double xx, double xy, double xz, double yx, double yy, double yz,
      double zx, double zy, double zz) {
    _rows[0][0] = xx;
    _rows[0][1] = xy;
    _rows[0][2] = xz;
    _rows[1][0] = yx;
    _rows[1][1] = yy;
    _rows[1][2] = yz;
    _rows[2][0] = zx;
    _rows[2][1] = zy;
    _rows[2][2] = zz;
  }

  ({Vector3 axis, double angle}) getAxisAngle() {
    // https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToAngle/index.htm
    double x, y, z; // Variables for result.
    if ((_rows[0][1] - _rows[1][0]).isZeroApprox() &&
        (_rows[0][2] - _rows[2][0]).isZeroApprox() &&
        (_rows[1][2] - _rows[2][1]).isZeroApprox()) {
      // Singularity found.
      // First check for identity matrix which must have +1 for all terms in leading diagonal and zero in other terms.
      if (isDiagonal() &&
          ((_rows[0][0] + _rows[1][1] + _rows[2][2] - 3).abs() <
              3 * _cmpEpsilon)) {
        // This singularity is identity matrix so angle = 0.
        return (axis: Vector3(x: 0, y: 1, z: 0), angle: 0);
      }
      // Otherwise this singularity is angle = 180.
      final xx = (_rows[0][0] + 1) / 2;
      final yy = (_rows[1][1] + 1) / 2;
      final zz = (_rows[2][2] + 1) / 2;
      final xy = (_rows[0][1] + _rows[1][0]) / 4;
      final xz = (_rows[0][2] + _rows[2][0]) / 4;
      final yz = (_rows[1][2] + _rows[2][1]) / 4;

      if ((xx > yy) && (xx > zz)) {
        // rows[0][0] is the largest diagonal term.
        if (xx < _cmpEpsilon) {
          x = 0;
          y = _sqrt12;
          z = _sqrt12;
        } else {
          x = math.sqrt(xx);
          y = xy / x;
          z = xz / x;
        }
      } else if (yy > zz) {
        // rows[1][1] is the largest diagonal term.
        if (yy < _cmpEpsilon) {
          x = _sqrt12;
          y = 0;
          z = _sqrt12;
        } else {
          y = math.sqrt(yy);
          x = xy / y;
          z = yz / y;
        }
      } else {
        // rows[2][2] is the largest diagonal term so base result on this.
        if (zz < _cmpEpsilon) {
          x = _sqrt12;
          y = _sqrt12;
          z = 0;
        } else {
          z = math.sqrt(zz);
          x = xz / z;
          y = yz / z;
        }
      }
      return (axis: Vector3(x: x, y: y, z: z), angle: math.pi);
    }

    // As we have reached here there are no singularities so we can handle normally.
    double s = math.sqrt(
        (_rows[2][1] - _rows[1][2]) * (_rows[2][1] - _rows[1][2]) +
            (_rows[0][2] - _rows[2][0]) * (_rows[0][2] - _rows[2][0]) +
            (_rows[1][0] - _rows[0][1]) *
                (_rows[1][0] - _rows[0][1])); // Used to normalize.

    if (s.abs() < _cmpEpsilon) {
      // Prevent divide by zero, should not happen if matrix is orthogonal and should be caught by singularity test above.
      s = 1;
    }

    x = (_rows[2][1] - _rows[1][2]) / s;
    y = (_rows[0][2] - _rows[2][0]) / s;
    z = (_rows[1][0] - _rows[0][1]) / s;

    return (
      axis: Vector3(x: x, y: y, z: z),
      angle: math.acos(
          ((_rows[0][0] + _rows[1][1] + _rows[2][2] - 1) / 2).clamp(0.0, 1.0))
    );
  }

  void setAxisAngle(Vector3 axis, double angle) {
    final axisSq =
        Vector3(x: axis.x * axis.x, y: axis.y * axis.y, z: axis.z * axis.z);
    final cosine = math.cos(angle);
    _rows[0][0] = axisSq.x + cosine * (1.0 - axisSq.x);
    _rows[1][1] = axisSq.y + cosine * (1.0 - axisSq.y);
    _rows[2][2] = axisSq.z + cosine * (1.0 - axisSq.z);

    final sine = math.sin(angle);
    final t = 1 - cosine;

    var xyzt = axis.x * axis.y * t;
    var zyxs = axis.z * sine;
    _rows[0][1] = xyzt - zyxs;
    _rows[1][0] = xyzt + zyxs;

    xyzt = axis.x * axis.z * t;
    zyxs = axis.y * sine;
    _rows[0][2] = xyzt + zyxs;
    _rows[2][0] = xyzt - zyxs;

    xyzt = axis.y * axis.z * t;
    zyxs = axis.x * sine;
    _rows[1][2] = xyzt - zyxs;
    _rows[2][1] = xyzt + zyxs;
  }

  void setAxisAngleScale(Vector3 axis, double angle, Vector3 scale) {
    _setDiagonal(scale);
    rotate(axis, angle);
  }

  void setEulerScale(Vector3 euler, Vector3 scale,
      {EulerOrder order = EulerOrder.yxz}) {
    _setDiagonal(scale);
    rotateEuler(euler, order: order);
  }

  void setQuaternionScale(Quaternion quaternion, Vector3 scale) {
    _setDiagonal(scale);
    rotateQuaternion(quaternion);
  }

  Vector3 getEuler({EulerOrder order = EulerOrder.yxz}) {
    switch (order) {
      case EulerOrder.xyz:
        {
          // Euler angles in XYZ convention.
          // See https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix
          //
          // rot =  cy*cz          -cy*sz           sy
          //        cz*sx*sy+cx*sz  cx*cz-sx*sy*sz -cy*sx
          //       -cx*cz*sy+sx*sz  cz*sx+cx*sy*sz  cx*cy

          Vector3 euler = Vector3();
          double sy = _rows[0][2];
          if (sy < (1.0 - _cmpEpsilon)) {
            if (sy > -(1.0 - _cmpEpsilon)) {
              // is this a pure Y rotation?
              if (_rows[1][0] == 0 &&
                  _rows[0][1] == 0 &&
                  _rows[1][2] == 0 &&
                  _rows[2][1] == 0 &&
                  _rows[1][1] == 1) {
                // return the simplest form (human friendlier in editor and scripts)
                euler.x = 0;
                euler.y = math.atan2(_rows[0][2], _rows[0][0]);
                euler.z = 0;
              } else {
                euler.x = math.atan2(-_rows[1][2], _rows[2][2]);
                euler.y = math.asin(sy);
                euler.z = math.atan2(-_rows[0][1], _rows[0][0]);
              }
            } else {
              euler.x = math.atan2(_rows[2][1], _rows[1][1]);
              euler.y = -math.pi / 2.0;
              euler.z = 0.0;
            }
          } else {
            euler.x = math.atan2(_rows[2][1], _rows[1][1]);
            euler.y = math.pi / 2.0;
            euler.z = 0.0;
          }
          return euler;
        }
      case EulerOrder.xzy:
        {
          // Euler angles in XZY convention.
          // See https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix
          //
          // rot =  cz*cy             -sz             cz*sy
          //        sx*sy+cx*cy*sz    cx*cz           cx*sz*sy-cy*sx
          //        cy*sx*sz          cz*sx           cx*cy+sx*sz*sy

          Vector3 euler = Vector3();
          double sz = _rows[0][1];
          if (sz < (1.0 - _cmpEpsilon)) {
            if (sz > -(1.0 - _cmpEpsilon)) {
              euler.x = math.atan2(_rows[2][1], _rows[1][1]);
              euler.y = math.atan2(_rows[0][2], _rows[0][0]);
              euler.z = math.asin(-sz);
            } else {
              // It's -1
              euler.x = -math.atan2(_rows[1][2], _rows[2][2]);
              euler.y = 0.0;
              euler.z = math.pi / 2.0;
            }
          } else {
            // It's 1
            euler.x = -math.atan2(_rows[1][2], _rows[2][2]);
            euler.y = 0.0;
            euler.z = -math.pi / 2.0;
          }
          return euler;
        }
      case EulerOrder.yxz:
        {
          // Euler angles in YXZ convention.
          // See https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix
          //
          // rot =  cy*cz+sy*sx*sz    cz*sy*sx-cy*sz        cx*sy
          //        cx*sz             cx*cz                 -sx
          //        cy*sx*sz-cz*sy    cy*cz*sx+sy*sz        cy*cx

          Vector3 euler = Vector3();
          double m12 = _rows[1][2];
          if (m12 < (1 - _cmpEpsilon)) {
            if (m12 > -(1 - _cmpEpsilon)) {
              // is this a pure X rotation?
              if (_rows[1][0] == 0 &&
                  _rows[0][1] == 0 &&
                  _rows[0][2] == 0 &&
                  _rows[2][0] == 0 &&
                  _rows[0][0] == 1) {
                // return the simplest form (human friendlier in editor and scripts)
                euler.x = math.atan2(-m12, _rows[1][1]);
                euler.y = 0;
                euler.z = 0;
              } else {
                euler.x = math.asin(-m12);
                euler.y = math.atan2(_rows[0][2], _rows[2][2]);
                euler.z = math.atan2(_rows[1][0], _rows[1][1]);
              }
            } else {
              // m12 == -1
              euler.x = math.pi * 0.5;
              euler.y = math.atan2(_rows[0][1], _rows[0][0]);
              euler.z = 0;
            }
          } else {
            // m12 == 1
            euler.x = -math.pi * 0.5;
            euler.y = -math.atan2(_rows[0][1], _rows[0][0]);
            euler.z = 0;
          }

          return euler;
        }
      case EulerOrder.yzx:
        {
          // Euler angles in YZX convention.
          // See https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix
          //
          // rot =  cy*cz             sy*sx-cy*cx*sz     cx*sy+cy*sz*sx
          //        sz                cz*cx              -cz*sx
          //        -cz*sy            cy*sx+cx*sy*sz     cy*cx-sy*sz*sx

          Vector3 euler = Vector3();
          double sz = _rows[1][0];
          if (sz < (1.0 - _cmpEpsilon)) {
            if (sz > (-1.0 - _cmpEpsilon)) {
              euler.x = math.atan2(-_rows[1][2], _rows[1][1]);
              euler.y = math.atan2(-_rows[2][0], _rows[0][0]);
              euler.z = math.asin(sz);
            } else {
              // It's -1
              euler.x = math.atan2(_rows[2][1], _rows[2][2]);
              euler.y = 0.0;
              euler.z = -math.pi / 2.0;
            }
          } else {
            // It's 1
            euler.x = math.atan2(_rows[2][1], _rows[2][2]);
            euler.y = 0.0;
            euler.z = math.pi / 2.0;
          }
          return euler;
        }
      case EulerOrder.zxy:
        {
          // Euler angles in ZXY convention.
          // See https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix
          //
          // rot =  cz*cy-sz*sx*sy    -cx*sz                cz*sy+cy*sz*sx
          //        cy*sz+cz*sx*sy    cz*cx                 sz*sy-cz*cy*sx
          //        -cx*sy            sx                    cx*cy
          Vector3 euler = Vector3();
          double sx = _rows[2][1];
          if (sx < (1.0 - _cmpEpsilon)) {
            if (sx > -(1.0 - _cmpEpsilon)) {
              euler.x = math.asin(sx);
              euler.y = math.atan2(-_rows[2][0], _rows[2][2]);
              euler.z = math.atan2(-_rows[0][1], _rows[1][1]);
            } else {
              // It's -1
              euler.x = -math.pi / 2.0;
              euler.y = math.atan2(_rows[0][2], _rows[0][0]);
              euler.z = 0;
            }
          } else {
            // It's 1
            euler.x = math.pi / 2.0;
            euler.y = math.atan2(_rows[0][2], _rows[0][0]);
            euler.z = 0;
          }
          return euler;
        }
      case EulerOrder.zyx:
        {
          // Euler angles in ZYX convention.
          // See https://en.wikipedia.org/wiki/Euler_angles#Rotation_matrix
          //
          // rot =  cz*cy             cz*sy*sx-cx*sz        sz*sx+cz*cx*cy
          //        cy*sz             cz*cx+sz*sy*sx        cx*sz*sy-cz*sx
          //        -sy               cy*sx                 cy*cx
          Vector3 euler = Vector3();
          double sy = _rows[2][0];
          if (sy < (1.0 - _cmpEpsilon)) {
            if (sy > -(1.0 - _cmpEpsilon)) {
              euler.x = math.atan2(_rows[2][1], _rows[2][2]);
              euler.y = math.asin(-sy);
              euler.z = math.atan2(_rows[1][0], _rows[0][0]);
            } else {
              // It's -1
              euler.x = 0;
              euler.y = math.pi / 2.0;
              euler.z = -math.atan2(_rows[0][1], _rows[1][1]);
            }
          } else {
            // It's 1
            euler.x = 0;
            euler.y = -math.pi / 2.0;
            euler.z = -math.atan2(_rows[0][1], _rows[1][1]);
          }
          return euler;
        }
    }
  }

  void setEuler(Vector3 euler, {EulerOrder order = EulerOrder.xyz}) {
    double c = math.cos(euler.x);
    double s = math.sin(euler.x);
    Basis xmat = Basis()..set(1, 0, 0, 0, c, -s, 0, s, c);

    c = math.cos(euler.y);
    s = math.sin(euler.y);
    Basis ymat = Basis()..set(c, 0, s, 0, 1, 0, -s, 0, c);

    c = math.cos(euler.z);
    s = math.sin(euler.z);
    Basis zmat = Basis()..set(c, -s, 0, s, c, 0, 0, 0, 1);

    switch (order) {
      case EulerOrder.xyz:
        _copy(xmat * (ymat * zmat));
        break;
      case EulerOrder.xzy:
        _copy(xmat * zmat * ymat);
        break;
      case EulerOrder.yxz:
        _copy(ymat * xmat * zmat);
        break;
      case EulerOrder.yzx:
        _copy(ymat * zmat * xmat);
        break;
      case EulerOrder.zxy:
        _copy(zmat * xmat * ymat);
        break;
      case EulerOrder.zyx:
        _copy(zmat * ymat * xmat);
        break;
    }
  }

  Quaternion getQuaternion() {
    /* Allow getting a quaternion from an unnormalized transform */
    Basis m = Basis.copy(this);
    double trace = m._rows[0][0] + m._rows[1][1] + m._rows[2][2];
    List<double> temp = List.filled(4, 0, growable: false);

    if (trace > 0.0) {
      double s = math.sqrt(trace + 1.0);
      temp[3] = (s * 0.5);
      s = 0.5 / s;

      temp[0] = ((m._rows[2][1] - m._rows[1][2]) * s);
      temp[1] = ((m._rows[0][2] - m._rows[2][0]) * s);
      temp[2] = ((m._rows[1][0] - m._rows[0][1]) * s);
    } else {
      int i = m._rows[0][0] < m._rows[1][1]
          ? (m._rows[1][1] < m._rows[2][2] ? 2 : 1)
          : (m._rows[0][0] < m._rows[2][2] ? 2 : 0);
      int j = (i + 1) % 3;
      int k = (i + 2) % 3;

      double s = math.sqrt(m._rows[i][i] - m._rows[j][j] - m._rows[k][k] + 1.0);
      temp[i] = s * 0.5;
      s = 0.5 / s;

      temp[3] = (m._rows[k][j] - m._rows[j][k]) * s;
      temp[j] = (m._rows[j][i] + m._rows[i][j]) * s;
      temp[k] = (m._rows[k][i] + m._rows[i][k]) * s;
    }

    return Quaternion.fromXYZW(temp[0], temp[1], temp[2], temp[3]);
  }

  void setQuaternion(Quaternion quaternion) {
    final d = quaternion.lengthSquared();
    final s = 2.0 / d;
    final xs = quaternion.x * s, ys = quaternion.y * s, zs = quaternion.z * s;
    final wx = quaternion.w * xs,
        wy = quaternion.w * ys,
        wz = quaternion.w * zs;
    final xx = quaternion.x * xs,
        xy = quaternion.x * ys,
        xz = quaternion.x * zs;
    final yy = quaternion.y * ys,
        yz = quaternion.y * zs,
        zz = quaternion.z * zs;
    set(1.0 - (yy + zz), xy - wz, xz + wy, xy + wz, 1.0 - (xx + zz), yz - wx,
        xz - wy, yz + wx, 1.0 - (xx + yy));
  }

  Vector3 getColumn(int index) {
    return Vector3(x: _rows[0][index], y: _rows[1][index], z: _rows[2][index]);
  }

  void setColumn(int index, Vector3 value) {
    _rows[0][index] = value.x;
    _rows[1][index] = value.y;
    _rows[2][index] = value.z;
  }

  void setColumns(Vector3 x, Vector3 y, Vector3 z) {
    setColumn(0, x);
    setColumn(1, y);
    setColumn(2, z);
  }

  bool isOrthogonal() {
    Basis identity = Basis();
    Basis m = this * transposed();

    return m.isEqualApprox(identity);
  }

  bool isDiagonal() {
    return (_rows[0][1].isZeroApprox() &&
        _rows[0][2].isZeroApprox() &&
        _rows[1][0].isZeroApprox() &&
        _rows[1][2].isZeroApprox() &&
        _rows[2][0].isZeroApprox() &&
        _rows[2][1].isZeroApprox());
  }

  bool isRotation() {
    return determinant().isEqualApprox(1) && isOrthogonal();
  }

  bool isEqualApprox(Basis basis) {
    return _rows[0].isEqualApprox(basis._rows[0]) &&
        _rows[1].isEqualApprox(basis._rows[1]) &&
        _rows[2].isEqualApprox(basis._rows[2]);
  }

  bool isFinite() {
    return _rows[0].isFinite() && _rows[1].isFinite() && _rows[2].isFinite();
  }

  double tdotx(Vector3 v) {
    return _rows[0][0] * v[0] + _rows[1][0] * v[1] + _rows[2][0] * v[2];
  }

  double tdoty(Vector3 v) {
    return _rows[0][1] * v[0] + _rows[1][1] * v[1] + _rows[2][1] * v[2];
  }

  double tdotz(Vector3 v) {
    return _rows[0][2] * v[0] + _rows[1][2] * v[1] + _rows[2][2] * v[2];
  }

  Vector3 xform(Vector3 vector) {
    return Vector3(
        x: _rows[0].dot(vector),
        y: _rows[1].dot(vector),
        z: _rows[2].dot(vector));
  }

  Vector3 xformInv(Vector3 vector) {
    return Vector3(
        x: (_rows[0][0] * vector.x) +
            (_rows[1][0] * vector.y) +
            (_rows[2][0] * vector.z),
        y: (_rows[0][1] * vector.x) +
            (_rows[1][1] * vector.y) +
            (_rows[2][1] * vector.z),
        z: (_rows[0][2] * vector.x) +
            (_rows[1][2] * vector.y) +
            (_rows[2][2] * vector.z));
  }

  Basis transposeXform(Basis m) {
    return Basis()
      ..set(
          _rows[0].x * m[0].x + _rows[1].x * m[1].x + _rows[2].x * m[2].x,
          _rows[0].x * m[0].y + _rows[1].x * m[1].y + _rows[2].x * m[2].y,
          _rows[0].x * m[0].z + _rows[1].x * m[1].z + _rows[2].x * m[2].z,
          _rows[0].y * m[0].x + _rows[1].y * m[1].x + _rows[2].y * m[2].x,
          _rows[0].y * m[0].y + _rows[1].y * m[1].y + _rows[2].y * m[2].y,
          _rows[0].y * m[0].z + _rows[1].y * m[1].z + _rows[2].y * m[2].z,
          _rows[0].z * m[0].x + _rows[1].z * m[1].x + _rows[2].z * m[2].x,
          _rows[0].z * m[0].y + _rows[1].z * m[1].y + _rows[2].z * m[2].y,
          _rows[0].z * m[0].z + _rows[1].z * m[1].z + _rows[2].z * m[2].z);
  }

  Basis operator *(dynamic other) {
    if (other is Basis) {
      return Basis()
        ..set(
          other.tdotx(_rows[0]),
          other.tdoty(_rows[0]),
          other.tdotz(_rows[0]),
          other.tdotx(_rows[1]),
          other.tdoty(_rows[1]),
          other.tdotz(_rows[1]),
          other.tdotx(_rows[2]),
          other.tdoty(_rows[2]),
          other.tdotz(_rows[2]),
        );
    } else if (other is num) {
      return Basis.copy(this)
        .._rows[0] *= other
        .._rows[1] *= other
        .._rows[2] *= other;
    }
    throw ArgumentError(
        'Unsuported type for Basis.operator*: ${other.runtimeType}');
  }

  Basis operator +(Basis matrix) {
    return Basis.copy(this)
      .._rows[0] += matrix._rows[0]
      .._rows[1] += matrix._rows[1]
      .._rows[2] += matrix._rows[2];
  }

  Basis operator -(Basis matrix) {
    return Basis.copy(this)
      .._rows[0] -= matrix._rows[0]
      .._rows[1] -= matrix._rows[1]
      .._rows[2] -= matrix._rows[2];
  }

  Vector3 operator [](int index) {
    return _rows[index];
  }

  @override
  bool operator ==(Object other) {
    if (other is! Basis) return false;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (_rows[i][j] != other._rows[i][j]) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  String toString() {
    return '[X: ${getColumn(0)}, Y: ${getColumn(1)}, Z: ${getColumn(2)}]';
  }

  void _setDiagonal(Vector3 diag) {
    _rows[0][0] = diag.x;
    _rows[0][1] = 0;
    _rows[0][2] = 0;

    _rows[1][0] = 0;
    _rows[1][1] = diag.y;
    _rows[1][2] = 0;

    _rows[2][0] = 0;
    _rows[2][1] = 0;
    _rows[2][2] = diag.z;
  }

  double _cofac(int row1, int col1, int row2, int col2) {
    return _rows[row1][col1] * _rows[row2][col2] -
        _rows[row1][col2] * _rows[row2][col1];
  }

  void _copy(Basis basis) {
    _rows[0] = Vector3.copy(basis._rows[0]);
    _rows[1] = Vector3.copy(basis._rows[1]);
    _rows[2] = Vector3.copy(basis._rows[2]);
  }

  @override
  void copyFrom(Pointer<Uint8> data) {
    final floatPtr = data.cast<Float>();
    _rows[0].copyFrom(floatPtr.cast());
    _rows[1].copyFrom((floatPtr + 3).cast());
    _rows[2].copyFrom((floatPtr + 6).cast());
  }

  @override
  void copyTo(Pointer<Uint8> data) {
    final floatPtr = data.cast<Float>();
    _rows[0].copyTo(floatPtr.cast());
    _rows[1].copyTo((floatPtr + 3).cast());
    _rows[2].copyTo((floatPtr + 6).cast());
  }

  static void initBindings() {
    // not sure if this is needed anymore
  }
}
