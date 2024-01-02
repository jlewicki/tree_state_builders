import 'dart:async';

typedef FutureOrBinder<T, R> = FutureOr<R> Function(T value);

extension FutureOrExtensions<T> on FutureOr<T> {
  /// Monadic bind operation for [FutureOr].
  FutureOr<R> bind<R>(FutureOrBinder<T, R> binder) {
    var futureOr = this;
    return futureOr is Future<T> ? futureOr.then(binder) : binder(futureOr);
  }
}

class Ref<T> {
  T value;
  Ref(this.value);
}

class TypeLiteral<T> {
  const TypeLiteral();
  Type get type => T;
}

bool isTypeOf<ThisType, OfType>() => _Phantom<ThisType>() is _Phantom<OfType>;

bool isTypeOfExact<ThisType, OfType>() =>
    TypeLiteral<ThisType>().type == TypeLiteral<OfType>().type;

class _Phantom<T> {}

/// Returns `true` if [value] is a member of an enumeration.
bool isEnumValue(Object value) {
  final split = value.toString().split('.');
  return split.length > 1 && split[0] == value.runtimeType.toString();
}

/// Returns a short description of an enum value.
///
/// This is indentical to `describeEnum` from Flutter, which can't be used directly from a pure Dart
/// library.
String describeEnum(Object enumEntry) {
  final String description = enumEntry.toString();
  final int indexOfDot = description.indexOf('.');
  assert(
    indexOfDot != -1 && indexOfDot < description.length - 1,
    'The provided object "$enumEntry" is not an enum.',
  );
  return description.substring(indexOfDot + 1);
}
