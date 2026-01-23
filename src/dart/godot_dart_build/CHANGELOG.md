## 0.11.0

- Remove the need to specify signal names on `@GodotSignal`
- Support `List<T>` on properties along with editor hints for properties. Automatically convert Godot `Array` to `List<T>`.

## 0.10.0

- BREAKING: Fix issues with hot reload on new scripts.

## 0.9.0

- Use `SignalX` over `Signal` for Dart defined signals.
- Emit a build error if a `@GodotExport` or `@GodotRpc` methoduses named parameters

## 0.8.0

- BREAKING: Major changes to support more restrictive native calls in Dart 3.8.

## 0.7.0

- Add the ability to use @GodotProperty on getters.
- Allow sending RPC messages to specific peers.
- Fix generation of RPCs in several situations.

## 0.6.0

- Update generation to not add "binding tokens" to TypeInfo (major refactor in `godot_dart` 0.8.0).
- Fix RPC generation to not create a private class.

## 0.5.0

- Support parameters on Signals with `SignalArgument`
- Fix using Dart defined scripts as GodotProperties.
- Add support for RPC methods.

## 0.4.0

- Add correct default property hints to Node and Resource types.

## 0.3.2

- Fix a different version constraint issue.

## 0.3.1

- Fix a version constraint issue.

## 0.3.0

- Improve Global Class hot reload by generating a list of available global classes.

## 0.2.0

- Add support for Godot Global Classes

## 0.1.0

- Initial version.
