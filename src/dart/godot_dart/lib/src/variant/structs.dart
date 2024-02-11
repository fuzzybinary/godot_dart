// These are structs that are used in Native Structures and need struct equivelents

import 'dart:ffi';

final class Vector2Struct extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
}

final class Vector3Struct extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double z;
}

final class Rect2Struct extends Struct {
  external Vector2Struct position;
  external Vector2Struct size;
}

final class RIDStruct extends Struct {
  @Int64()
  external int id;
}

final class StringNameStruct extends Struct {
  @Int64()
  external int hash;
}

final class ObjectIDStruct extends Struct {
  @Uint64()
  external int id;
}
