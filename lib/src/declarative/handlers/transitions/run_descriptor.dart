import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_builders/declarative.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeRunDescriptor<D, C>(
  StateKey forState,
  FutureOr<void> Function(TransitionHandlerContext<D, C> ctx) handler,
  FutureOr<C> Function(TransitionContext) makeContext,
  Logger log,
  String? label,
) {
  var info = TransitionHandlerInfo(TransitionHandlerType.run, [], label);
  return TransitionHandlerDescriptor<C>(
      info,
      makeContext,
      (descrCtx) => (transCtx) {
            var data = forState is DataStateKey<D>
                ? transCtx.data(forState).value
                : null as D;
            var ctx =
                TransitionHandlerContext<D, C>(transCtx, data, descrCtx.ctx);
            return handler(ctx);
          });
}
