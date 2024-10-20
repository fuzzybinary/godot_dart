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
