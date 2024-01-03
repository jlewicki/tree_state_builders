import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_builders/declarative.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import './transition_handler_descriptor.dart';
import '../../../utility.dart';

TransitionHandlerDescriptor<C> makeScheduleDescriptor<D, C, M>(
  StateKey forState,
  M Function(TransitionHandlerContext<D, C> ctx) getValue,
  Duration duration,
  bool periodic,
  FutureOr<C> Function(TransitionContext) makeContext,
  Logger log,
  String messageType,
  String? label,
) {
  var info = TransitionHandlerInfo(
      TransitionHandlerType.schedule, [], label, messageType);
  return TransitionHandlerDescriptor<C>(
    info,
    makeContext,
    (descrCtx) => (transCtx) {
      // TODO: reconsider getMessage. It probably shouldnt accept a transCtx, or alternatively
      // the function passed to schedule should accept a transCtx (which should be OK since the
      // timer is cancelled when state is exited)
      var data = forState is DataStateKey<D>
          ? transCtx.data(forState).value
          : null as D;
      var ctx = TransitionHandlerContext<D, C>(transCtx, data, descrCtx.ctx);
      var msg = getValue(ctx).bind((msg) => msg as Object);
      transCtx.schedule(() => msg, duration: duration, periodic: periodic);
    },
  );
}
