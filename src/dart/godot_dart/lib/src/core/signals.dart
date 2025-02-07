import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

import '../gen/builtins.dart';
import 'core_types.dart';
import 'gdextension.dart';
import '../variant/variant.dart';
import '../gen/engine_classes.dart';

final Random _rand = Random();

/// Used to encapsulate creating subscription keys. The method for doing
/// this is to generate a random number and store the subscription there,
/// returning the random number as the subscription key. If there is already
/// a subscription at that location, it generates another random number. This
/// may not be the best method long term but it should work for now.
class _SubscriptionMap<F extends Function> {
  final SignalCallable parent;

  final Map<int, (ExtensionType, F)> _map = {};
  final Map<ExtensionType, List<int>> _targetSubscriptions = {};

  _SubscriptionMap(this.parent);

  Iterable<F> get values sync* {
    for (final val in _map.values) {
      yield val.$2;
    }
  }

  void clear() {
    _map.clear();
    for (final target in _targetSubscriptions.keys) {
      target.detachSignal(parent);
    }
    _targetSubscriptions.clear();
  }

  int subscribe(ExtensionType target, F func) {
    int? key;
    while (key == null) {
      key = _rand.nextInt(1 << 32);
      if (_map.containsKey(key)) {
        key = null;
        continue;
      }
      _map[key] = (target, func);
      if (_targetSubscriptions[target] != null) {
        _targetSubscriptions[target]!.add(key);
      } else {
        _targetSubscriptions[target] = [key];
        target.attachSignal(parent);
      }
    }

    return key;
  }

  void unsubscribe(int key) {
    final value = _map.remove(key);
    if (value != null) {
      final target = value.$1;
      final targetList = _targetSubscriptions[target];
      targetList?.remove(key);
      target.detachSignal(parent);
    }
  }

  void unsubscribeAll(ExtensionType target) {
    final targetSubscription = _targetSubscriptions.remove(target);
    if (targetSubscription != null) {
      for (final key in targetSubscription) {
        _map.remove(key);
      }
    }
  }
}

@internal
abstract class SignalCallable {
  static final _targetFinalizer = Finalizer<SignalCallable>((self) {
    self.clear();
  });

  final String name;
  final int arguments;

  SignalCallable(GodotObject object, this.name, this.arguments) {
    final callable = _createSignalCallableBinding(this, object);
    object.connect(name, callable);
    _targetFinalizer.attach(object, this);
  }

  Callable _createSignalCallableBinding(
      SignalCallable callable, GodotObject binding) {
    final result = gde.dartBindings
        .createSignalCallable(callable, binding.getInstanceId());
    return result as Callable;
  }

  void clear();
  void unsubscribeAll(GodotObject target);
}

class Signal0 extends SignalCallable {
  late _SubscriptionMap<void Function()> _subscriptions;

  Signal0(GodotObject object, String name) : super(object, name, 0) {
    _subscriptions = _SubscriptionMap<void Function()>(this);
  }

  @pragma('vm:entry-point')
  void call(List<Variant> args) {
    for (final sub in _subscriptions.values) {
      sub();
    }
  }

  int connect(GodotObject target, void Function() func) {
    final subscription = _subscriptions.subscribe(target, func);
    return subscription;
  }

  void disconnect(int subscriptionKey) {
    _subscriptions.unsubscribe(subscriptionKey);
  }

  Future<void> asFuture(GodotObject target) {
    final completer = Completer<void>();
    var subscriptionKey = 0;
    subscriptionKey = connect(target, () {
      completer.complete();
    });

    completer.future.then((_) {
      disconnect(subscriptionKey);
    });
    return completer.future;
  }

  @override
  void unsubscribeAll(GodotObject target) {
    _subscriptions.unsubscribeAll(target);
  }

  @override
  void clear() => _subscriptions.clear();
}

class Signal1<P1> extends SignalCallable {
  late _SubscriptionMap<void Function(P1)> _subscriptions;

  Signal1(GodotObject object, String name) : super(object, name, 1) {
    _subscriptions = _SubscriptionMap<void Function(P1)>(this);
  }

  @pragma('vm:entry-point')
  void call(List<Variant> args) {
    for (final sub in _subscriptions.values) {
      sub(args[0].cast<P1>() as P1);
    }
  }

  int connect(GodotObject target, void Function(P1) func) {
    return _subscriptions.subscribe(target, func);
  }

  void disconnect(int subscriptionKey) {
    _subscriptions.unsubscribe(subscriptionKey);
  }

  Future<P1> asFuture(GodotObject target) {
    final completer = Completer<P1>();
    var subscriptionKey = 0;
    subscriptionKey = connect(target, (p1) {
      completer.complete(p1);
    });

    completer.future.then((_) {
      disconnect(subscriptionKey);
    });

    return completer.future;
  }

  @override
  void clear() => _subscriptions.clear();

  @override
  void unsubscribeAll(GodotObject target) {
    _subscriptions.unsubscribeAll(target);
  }
}

class Signal2<P1, P2> extends SignalCallable {
  late _SubscriptionMap<void Function(P1, P2)> _subscriptions;

  Signal2(GodotObject object, String name) : super(object, name, 2) {
    _subscriptions = _SubscriptionMap<void Function(P1, P2)>(this);
  }

  @pragma('vm:entry-point')
  void call(List<Variant> args) {
    for (final sub in _subscriptions.values) {
      sub(
        args[0].cast<P1>() as P1,
        args[1].cast<P2>() as P2,
      );
    }
  }

  int connect(GodotObject target, void Function(P1, P2) func) {
    return _subscriptions.subscribe(target, func);
  }

  void disconnect(int subscriptionKey) {
    _subscriptions.unsubscribe(subscriptionKey);
  }

  Future<(P1, P2)> asFuture(GodotObject target) {
    final completer = Completer<(P1, P2)>();
    var subscriptionKey = 0;
    subscriptionKey = connect(target, (p1, p2) {
      completer.complete((p1, p2));
    });

    completer.future.then((_) {
      disconnect(subscriptionKey);
    });

    return completer.future;
  }

  @override
  void clear() => _subscriptions.clear();

  @override
  void unsubscribeAll(ExtensionType target) {
    _subscriptions.unsubscribeAll(target);
  }
}

class Signal3<P1, P2, P3> extends SignalCallable {
  late _SubscriptionMap<void Function(P1, P2, P3)> _subscriptions;

  Signal3(GodotObject object, String name) : super(object, name, 3) {
    _subscriptions = _SubscriptionMap<void Function(P1, P2, P3)>(this);
  }

  @pragma('vm:entry-point')
  void call(List<Variant> args) {
    for (final sub in _subscriptions.values) {
      sub(
        args[0].cast<P1>() as P1,
        args[1].cast<P2>() as P2,
        args[2].cast<P3>() as P3,
      );
    }
  }

  int connect(GodotObject target, void Function(P1, P2, P3) func) {
    return _subscriptions.subscribe(target, func);
  }

  void disconnect(int subscriptionKey) {
    _subscriptions.unsubscribe(subscriptionKey);
  }

  Future<(P1, P2, P3)> asFuture(GodotObject target) {
    final completer = Completer<(P1, P2, P3)>();
    var subscriptionKey = 0;
    subscriptionKey = connect(target, (p1, p2, p3) {
      completer.complete((p1, p2, p3));
    });

    completer.future.then((_) {
      disconnect(subscriptionKey);
    });

    return completer.future;
  }

  @override
  void clear() => _subscriptions.clear();

  @override
  void unsubscribeAll(GodotObject target) {
    _subscriptions.unsubscribeAll(target);
  }
}

class Signal4<P1, P2, P3, P4> extends SignalCallable {
  late _SubscriptionMap<void Function(P1, P2, P3, P4)> _subscriptions;

  Signal4(GodotObject object, String name) : super(object, name, 3) {
    _subscriptions = _SubscriptionMap<void Function(P1, P2, P3, P4)>(this);
  }

  @pragma('vm:entry-point')
  void call(List<Variant> args) {
    for (final sub in _subscriptions.values) {
      sub(
        args[0].cast<P1>() as P1,
        args[1].cast<P2>() as P2,
        args[2].cast<P3>() as P3,
        args[3].cast<P4>() as P4,
      );
    }
  }

  int connect(GodotObject target, void Function(P1, P2, P3, P4) func) {
    return _subscriptions.subscribe(target, func);
  }

  void disconnect(int subscriptionKey) {
    _subscriptions.unsubscribe(subscriptionKey);
  }

  Future<(P1, P2, P3, P4)> asFuture(GodotObject target) {
    final completer = Completer<(P1, P2, P3, P4)>();
    var subscriptionKey = 0;
    subscriptionKey = connect(target, (p1, p2, p3, p4) {
      completer.complete((p1, p2, p3, p4));
    });

    completer.future.then((_) {
      disconnect(subscriptionKey);
    });

    return completer.future;
  }

  @override
  void clear() => _subscriptions.clear();

  @override
  void unsubscribeAll(GodotObject target) {
    _subscriptions.unsubscribeAll(target);
  }
}

class Signal5<P1, P2, P3, P4, P5> extends SignalCallable {
  late _SubscriptionMap<void Function(P1, P2, P3, P4, P5)> _subscriptions;

  Signal5(GodotObject object, String name) : super(object, name, 5) {
    _subscriptions = _SubscriptionMap<void Function(P1, P2, P3, P4, P5)>(this);
  }

  @pragma('vm:entry-point')
  void call(List<Variant> args) {
    for (final sub in _subscriptions.values) {
      sub(
        args[0].cast<P1>() as P1,
        args[1].cast<P2>() as P2,
        args[2].cast<P3>() as P3,
        args[3].cast<P4>() as P4,
        args[4].cast<P5>() as P5,
      );
    }
  }

  int connect(GodotObject target, void Function(P1, P2, P3, P4, P5) func) {
    return _subscriptions.subscribe(target, func);
  }

  void disconnect(int subscriptionKey) {
    _subscriptions.unsubscribe(subscriptionKey);
  }

  Future<(P1, P2, P3, P4, P5)> asFuture(GodotObject target) {
    final completer = Completer<(P1, P2, P3, P4, P5)>();
    var subscriptionKey = 0;
    subscriptionKey = connect(target, (p1, p2, p3, p4, p5) {
      completer.complete((p1, p2, p3, p4, p5));
    });

    completer.future.then((_) {
      disconnect(subscriptionKey);
    });

    return completer.future;
  }

  @override
  void clear() => _subscriptions.clear();

  @override
  void unsubscribeAll(GodotObject target) {
    _subscriptions.unsubscribeAll(target);
  }
}
