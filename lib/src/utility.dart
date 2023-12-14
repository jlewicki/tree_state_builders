import 'dart:async';

typedef FutureOrBinder<T, R> = FutureOr<R> Function(T value);

extension FutureOrExtensions<T> on FutureOr<T> {
  /// Monadic bind operation for [FutureOr].
  FutureOr<R> bind<R>(FutureOrBinder<T, R> binder) {
    var futureOr = this;
    return futureOr is Future<T> ? futureOr.then(binder) : binder(futureOr);
  }
}
