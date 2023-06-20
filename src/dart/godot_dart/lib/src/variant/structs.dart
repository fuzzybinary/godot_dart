// These are structs that are used in Native Structures and need struct equivelents

import 'dart:ffi';

class Vector2Struct extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
}

class Vector3Struct extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double z;
}

class Rect2Struct extends Struct {
  external Vector2Struct position;
  external Vector2Struct size;
}

class RIDStruct extends Struct {
  @Int64()
  external int id;
}

class StringNameStruct extends Struct {
  @Int64()
  external int hash;
}

class ObjectIDStruct extends Struct {
  @Uint64()
  external int id;
}
