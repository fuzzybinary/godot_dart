## 0.6.1

- Fix `Variant.cast` to correctly return null in cases where the Variant is null.

## 0.6.0

- Adjust generate global constats to avoid unnecessary prefixes.
- Have `Variant.getType` return `VariantType` instead of int.
- Add `Variant.cast` to support getting an object directly from a Variant.
- Add generation of Godot utility functions under `GD` static class.
- Add `getWeak` extension method on `GodotObject`.

## 0.5.2

- Fix `Future<void>` throwing an error when put in a Variant, which could happen with `async` signal recievers.

## 0.5.1

- Bind `CallbackAwaiter` during initialization.

## 0.5.0

- Variant can now be constructed from an Object without using `fromObject`
- Variants that had `.fromGDString` now also have `.fromString` constructors
- Added `CallbackAwaiter` which allows you to await a Callable being called.

## 0.4.0

- Improve Global Class hot reload by having the generator create a list of available global classes.

## 0.3.0

- Add support for Godot Global Classes

## 0.2.0

- Replace variant call with "ptr" calls, which are faster
- Fix varargs methods in engine classes.

## 0.1.1

- Fix missing generated libraries

## 0.1.0

- Initial version.
