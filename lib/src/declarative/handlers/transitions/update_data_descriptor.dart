import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_builders/declarative.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeUpdateDataDescriptor<C, D>(
  DataStateKey<D> forState,
  D Function(TransitionHandlerContext<D, C>) update,
  FutureOr<C> Function(TransitionContext) makeContext,
  StateKey? state,
  Logger log,
  String? label,
) {
  var info = TransitionHandlerInfo(
      TransitionHandlerType.updateData, [], label, null, D);
  return TransitionHandlerDescriptor<C>(
      info,
      makeContext,
      (descrCtx) => (transCtx) {
            var data = transCtx.data(forState);
            var ctx = TransitionHandlerContext<D, C>(
                transCtx, data.value, descrCtx.ctx);
            data.update((d) => update(ctx));
          });
}
