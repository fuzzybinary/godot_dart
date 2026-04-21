import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';
import 'variant.dart';

class Transform3D extends CopyiedBuiltinType {
  static const int _size = 48;
  static final sTypeInfo = BuiltinTypeInfo<Transform3D>(
    className: StringName.fromString('Transform3D'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,
    size: _size,
    constructObjectDefault: () => Transform3D(),
    constructCopy: (ptr) => Transform3D.copyPtr(ptr),
  );

  Basis basis = Basis();
  Vector3 origin = Vector3();

  @override
  BuiltinTypeInfo<Transform3D> get typeInfo => sTypeInfo;

  Transform3D();

  Transform3D.fromBasisOrigin(Basis basis, Vector3 origin)
      : basis = Basis.copy(basis),
        origin = Vector3.copy(origin);

  Transform3D.fromXAxisYAxisZAxisOrigin(
      Vector3 x, Vector3 y, Vector3 z, Vector3 origin)
      : origin = Vector3.copy(origin) {
    basis.setColumn(0, x);
    basis.setColumn(1, y);
    basis.setColumn(2, z);
  }

  Transform3D.copy(Transform3D other)
      : basis = Basis.copy(other.basis),
        origin = Vector3.copy(other.origin);

  Transform3D.copyPtr(Pointer<Void> pointer) {
    copyFrom(pointer.cast());
  }

  Transform3D.fromVariant(Variant variant)
      : this.fromVariantPtr(variant.nativePtr.cast());

  @internal
  Transform3D.fromVariantPtr(GDExtensionVariantPtr variantPtr) {
    final c = getToTypeConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_TRANSFORM3D);
    if (c == null) return;

    using((arena) {
      final nativeMem = arena.allocate<Uint8>(_size);

      c(nativeMem.cast(), variantPtr);
      copyFrom(nativeMem);
    });
  }

  void invert() {
    basis.transpose();
    origin = basis.xform(-origin);
  }

  Transform3D inverse() {
    // FIXME: this function assumes the basis is a rotation matrix, with no scaling.
    // Transform3D::affine_inverse can handle matrices with scaling, so GDScript
    // should eventually use that.
    Transform3D ret = Transform3D.copy(this);
    ret.invert();
    return ret;
  }

  void affineInvert() {
    basis.invert();
    origin = basis.xform(-origin);
  }

  Transform3D affineInverse() {
    Transform3D ret = Transform3D.copy(this);
    ret.affineInvert();
    return ret;
  }

  void rotate(Vector3 axis, double angle) {
    _copy(rotated(axis, angle));
  }

  Transform3D rotated(Vector3 axis, double angle) {
    // Equivalent to left multiplication
    Basis pBasis = Basis.fromAxisAngle(axis, angle);
    return Transform3D.fromBasisOrigin(pBasis * basis, pBasis.xform(origin));
  }

  Transform3D rotatedLocal(Vector3 axis, double angle) {
    // Equivalent to right multiplication
    Basis pBasis = Basis.fromAxisAngle(axis, angle);
    return Transform3D.fromBasisOrigin(basis * pBasis, origin);
  }

  void rotateBasis(Vector3 axis, double angle) {
    basis.rotate(axis, angle);
  }

  void setLookAt(Vector3 eye, Vector3 target, {Vector3? up}) {
    up ??= Vector3.up();
    basis = Basis.lookingAt(target - eye, up: up);
    origin = eye;
  }

  Transform3D lookingAt(Vector3 target, {Vector3? up}) {
    up ??= Vector3.up();
    return Transform3D.fromBasisOrigin(Basis.lookingAt(target, up: up), origin);
  }

  void scale(Vector3 scale) {
    basis.scale(scale);
    origin *= scale;
  }

  Transform3D scaled(Vector3 scale) {
    // Equivalent to left multiplication
    return Transform3D.fromBasisOrigin(basis.scaled(scale), origin * scale);
  }

  Transform3D scaledLocal(Vector3 scale) {
    // Equivalent to right multiplication
    return Transform3D.fromBasisOrigin(basis.scaledLocal(scale), origin);
  }

  void scaleBasis(Vector3 scale) {
    basis.scale(scale);
  }

  void translateLocal(double tx, double ty, double tz) {
    translateLocalVector3(Vector3(x: tx, y: ty, z: tz));
  }

  void translateLocalVector3(Vector3 translation) {
    for (int i = 0; i < 3; i++) {
      origin[i] += basis[i].dot(translation);
    }
  }

  Transform3D translated(Vector3 translation) {
    // Equivalent to left multiplication
    return Transform3D.fromBasisOrigin(basis, origin + translation);
  }

  Transform3D translatedLocal(Vector3 translation) {
    // Equivalent to right multiplication
    return Transform3D.fromBasisOrigin(
        basis, origin + basis.xform(translation));
  }

  void orthonormalize() {
    basis.orthonormalize();
  }

  Transform3D orthonormalized() {
    return Transform3D.copy(this)..orthonormalize();
  }

  void orthogonalize() {
    basis.orthogonalize();
  }

  Transform3D orthogonalized() {
    return Transform3D.copy(this)..orthogonalize();
  }

  bool isEqualApprox(Transform3D other) {
    return basis.isEqualApprox(other.basis) &&
        origin.isEqualApprox(other.origin);
  }

  bool isFinite() {
    return basis.isFinite() && origin.isFinite();
  }

  Vector3 xformVector3(Vector3 vector) {
    return Vector3(
        x: basis[0].dot(vector) + origin.x,
        y: basis[1].dot(vector) + origin.y,
        z: basis[2].dot(vector) + origin.z);
  }

  Vector3 xformInvVector3(Vector3 vector) {
    Vector3 v = vector - origin;

    return Vector3(
        x: (basis[0][0] * v.x) + (basis[1][0] * v.y) + (basis[2][0] * v.z),
        y: (basis[0][1] * v.x) + (basis[1][1] * v.y) + (basis[2][1] * v.z),
        z: (basis[0][2] * v.x) + (basis[1][2] * v.y) + (basis[2][2] * v.z));
  }

  AABB xformAABB(AABB aabb) {
    /* https://dev.theomader.com/transform-bounding-boxes/ */
    Vector3 min = aabb.position;
    Vector3 max = aabb.position + aabb.size;
    Vector3 tmin = Vector3(), tmax = Vector3();
    for (int i = 0; i < 3; i++) {
      tmin[i] = tmax[i] = origin[i];
      for (int j = 0; j < 3; j++) {
        double e = basis[i][j] * min[j];
        double f = basis[i][j] * max[j];
        if (e < f) {
          tmin[i] += e;
          tmax[i] += f;
        } else {
          tmin[i] += f;
          tmax[i] += e;
        }
      }
    }
    AABB rAabb = AABB.fromPositionSize(tmin, tmax - tmin);
    return rAabb;
  }

  AABB xformInv(AABB aabb) {
    // TODO: This is an optimization to prevent repeated jumping to Godot to retrieve
    // these members, but isn't necessary if AABB is implemented in Dart.
    Vector3 aabbPosition = aabb.position;
    Vector3 aabbSize = aabb.size;

    List<Vector3> vertices = [
      Vector3(
          x: aabbPosition.x + aabbSize.x,
          y: aabbPosition.y + aabbSize.y,
          z: aabbPosition.z + aabbSize.z),
      Vector3(
          x: aabbPosition.x + aabbSize.x,
          y: aabbPosition.y + aabbSize.y,
          z: aabbPosition.z),
      Vector3(
          x: aabbPosition.x + aabbSize.x,
          y: aabbPosition.y,
          z: aabbPosition.z + aabbSize.z),
      Vector3(
          x: aabbPosition.x + aabbSize.x, y: aabbPosition.y, z: aabbPosition.z),
      Vector3(
          x: aabbPosition.x,
          y: aabbPosition.y + aabbSize.y,
          z: aabbPosition.z + aabbSize.z),
      Vector3(
          x: aabbPosition.x, y: aabbPosition.y + aabbSize.y, z: aabbPosition.z),
      Vector3(
          x: aabbPosition.x, y: aabbPosition.y, z: aabbPosition.z + aabbSize.z),
      Vector3(x: aabbPosition.x, y: aabbPosition.y, z: aabbPosition.z)
    ];

    AABB ret = AABB();

    ret.position = xformInvVector3(vertices[0]);

    for (int i = 1; i < 8; i++) {
      ret.expand(xformInvVector3(vertices[i]));
    }

    return ret;
  }

  PackedVector3Array xformPackedVector3Array(PackedVector3Array array) {
    PackedVector3Array retArray = PackedVector3Array();
    retArray.resize(array.size());

    for (int i = 0; i < array.size(); ++i) {
      retArray[i] = xformVector3(array[i]);
    }
    return retArray;
  }

  PackedVector3Array xformInvPackedVector3Array(PackedVector3Array array) {
    PackedVector3Array retArray = PackedVector3Array();
    retArray.resize(array.size());

    for (int i = 0; i < array.size(); ++i) {
      retArray[i] = xformInvVector3(array[i]);
    }
    return retArray;
  }

  // Neither the plane regular xform or xform_inv are particularly efficient,
  // as they do a basis inverse. For xforming a large number
  // of planes it is better to pre-calculate the inverse transpose basis once
  // and reuse it for each plane, by using the 'fast' version of the functions.
  Plane xformPlane(Plane plane) {
    Basis b = basis.inverse();
    b.transpose();
    return xformPlaneFast(plane, b);
  }

  Plane xformInvPlane(Plane plane) {
    Transform3D inv = affineInverse();
    Basis basisTranspose = basis.transposed();
    return xformInvPlaneFast(plane, inv, basisTranspose);
  }

  Plane xformPlaneFast(Plane plane, Basis inverseTranspose) {
    Vector3 point = plane.normal * plane.d;
    point = xformVector3(point);

    // Use inverse transpose for correct normals with non-uniform scaling.
    Vector3 normal = inverseTranspose.xform(plane.normal);
    normal.normalize();

    double d = normal.dot(point);
    return Plane.fromNormalD(normal, d);
  }

  Plane xformInvPlaneFast(Plane plane, Transform3D inverse, Basis transpose) {
    // Transform a single point on the plane.
    Vector3 point = plane.normal * plane.d;
    point = inverse.xformVector3(point);

    // Note that instead of precalculating the transpose, an alternative
    // would be to use the transpose for the basis transform.
    // However that would be less SIMD friendly (requiring a swizzle).
    // So the cost is one extra precalced value in the calling code.
    // This is probably worth it, as this could be used in bottleneck areas. And
    // where it is not a bottleneck, the non-fast method is fine.

    // Use transpose for correct normals with non-uniform scaling.
    Vector3 normal = transpose.xform(plane.normal);
    normal.normalize();

    double d = normal.dot(point);
    return Plane.fromNormalD(normal, d);
  }

  Transform3D interpolateWith(Transform3D transform, double c) {
    Transform3D interp = Transform3D();

    Vector3 srcScale = basis.getScale();
    Quaternion srcRot = basis.getRotationQuaternion();
    Vector3 srcLoc = origin;

    Vector3 dstScale = transform.basis.getScale();
    Quaternion dstRot = transform.basis.getRotationQuaternion();
    Vector3 dstLoc = transform.origin;

    interp.basis.setQuaternionScale(
        srcRot.slerp(dstRot, c).normalized(), srcScale.lerp(dstScale, c));
    interp.origin = srcLoc.lerp(dstLoc, c);

    return interp;
  }

  Transform3D inverseXform(Transform3D t) {
    Vector3 v = t.origin - origin;
    return Transform3D.fromBasisOrigin(
        basis.transposeXform(t.basis), basis.xform(v));
  }

  Transform3D operator *(dynamic other) {
    if (other is num) {
      return Transform3D.fromBasisOrigin(
        basis * other,
        origin * other,
      );
    } else if (other is Transform3D) {
      return Transform3D.fromBasisOrigin(
        basis * other.basis,
        xformVector3(other.origin),
      );
    }
    throw ArgumentError(
        'Unsuported type for Transform3D.operator*: ${other.runtimeType}');
  }

  @override
  void copyTo(Pointer<Uint8> data) {
    basis.copyTo(data);
    origin.copyTo(data + Basis.sTypeInfo.size);
  }

  @override
  void copyFrom(Pointer<Uint8> data) {
    basis.copyFrom(data);
    origin.copyFrom(data + Basis.sTypeInfo.size);
  }

  void _copy(Transform3D transform) {
    basis = Basis.copy(transform.basis);
    origin = Vector3.copy(transform.origin);
  }

  static void initBindings() {
    // not sure if this is needed anymore
  }
}
