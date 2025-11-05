## 0.10.1

- Fix missing `@pragma` on `_isReloading`

## 0.10.0

- BREAKING: Fix extension to work with more restrictive native calls in Dart 3.8. 
    - For scripts, `godot_dart_build` should do most migration for you, but you need to add `@pragma('vm:entry-point')` onto your declaration for `sTypeInfo` in all script classes
    - Extension classes very different, and it is recommended to avoid using them for now. 

## 0.9.0

- Add type safe `SignalX` objects supporting automatic registering / deregistering.
- Fixed an issue with ScriptInstances not detaching themselves from their Dart counterparts on deletion.
- Attempted to refactor several files to make analysis faster.
- Fix weak conversion from `StringName` / `GDString` in `Variant.cast`

## 0.8.0

- Fix casting to builtin types from `Variant`.
- BREAKING: Remove `bindingToken` as a paremeter of type info. Simplified instance binding creation which should also lower the extension's memory usage.
- BREAKING: Remove `GodotObject.cast<T>` as Dart downcasting now works. Replaced with `GodotObject.as<T>`. This extension may be removed entirely in future versions.

## 0.7.0

- Support parameters on Signals with `SignalArgument`
- Fix using Dart defined scripts as GodotProperties.
- Add support for RPC methods.

## 0.6.2

- Fix a crash when using the indexed getter on `Array`

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
