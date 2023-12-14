import 'dart:async';

import 'package:tree_state_machine/tree_state_machine.dart';
import '../../../utility.dart';

enum MessageHandlerType {
  goto,
  gotoSelf,
  stay,
  when,
  whenWithContext,
  whenResult,
  unhandled,
  handler
}

class MessageHandlerInfo {
  MessageHandlerInfo(
    this.handlerType,
    this.messageType,
    this.actions,
    this.conditions,
    this._messageName,
    this.label,
    this.metadata, [
    this.goToTarget,
  ]);

  /// Indicates the way in which this message handler handles a message.
  final MessageHandlerType handlerType;

  /// The type of the message that is handled by this handler.
  final Type messageType;

  /// Conditions that mi
  final Iterable<MessageConditionInfo> conditions;

  /// Metadata
  final Map<String, Object>? metadata;

  // Actions that this handler will perform when handling a message.
  final List<MessageActionInfo> actions;
  final String? _messageName;
  final String? label;
  final StateKey? goToTarget;

  String get messageName => _messageName ?? messageType.toString();
}

enum ActionType { schedule, post, updateData, run }

class MessageActionInfo {
  final ActionType actionType;
  final Type? postMessageType;
  final Type? updateDataType;
  final String? label;

  MessageActionInfo(
    this.actionType,
    this.postMessageType,
    this.updateDataType,
    this.label,
  );
}

class MessageConditionInfo {
  final String? label;
  final MessageHandlerInfo whenTrueInfo;
  MessageConditionInfo(this.label, this.whenTrueInfo);
}

class MessageHandlerDescriptorContext<C> {
  final MessageContext msgCtx;
  final C ctx;
  MessageHandlerDescriptorContext(this.msgCtx, this.ctx);
}

class MessageHandlerDescriptor<C> {
  final MessageHandlerInfo info;
  final FutureOr<C> Function(MessageContext) makeContext;
  final MessageHandler Function(MessageHandlerDescriptorContext<C>)
      makeHandlerFromContext;

  MessageHandlerDescriptor(
      this.info, this.makeContext, this.makeHandlerFromContext);

  MessageHandler makeHandler() {
    return (msgCtx) {
      return makeContext(msgCtx).bind((ctx) {
        var descrCtx = MessageHandlerDescriptorContext<C>(msgCtx, ctx);
        var handler = makeHandlerFromContext(descrCtx);
        return handler(msgCtx);
      });
    };
  }
}
