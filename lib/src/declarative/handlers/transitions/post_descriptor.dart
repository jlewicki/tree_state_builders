import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_builders/declarative.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import './transition_handler_descriptor.dart';
import '../../../utility.dart';

TransitionHandlerDescriptor<C> makePostDescriptor<D, C, M>(
  StateKey forState,
  FutureOr<M> Function(TransitionHandlerContext<D, C> ctx) getMessage,
  FutureOr<C> Function(TransitionContext) makeContext,
  Logger log,
  String messageType,
  String? label,
) {
  var info =
      TransitionHandlerInfo(TransitionHandlerType.post, [], label, messageType);
  return TransitionHandlerDescriptor<C>(
    info,
    makeContext,
    (descrCtx) => (transCtx) {
      var data = forState is DataStateKey<D>
          ? transCtx.data(forState).value
          : null as D;
      var ctx = TransitionHandlerContext<D, C>(transCtx, data, descrCtx.ctx);
      var msg = getMessage(ctx).bind((msg) => msg as Object);
      transCtx.post(msg);
    },
  );
}
