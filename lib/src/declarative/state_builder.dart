part of '../../declarative.dart';

/// Indicates that a value of type [P] must be provided when entering a state.
///
/// [EntryChannel] serves as a contract indicating that in order to transition to a particular
/// state, additional contextual information of type [P] must be provided by the transition source.
///
/// ```dart
/// class SubmitCredentials {}
/// class AuthenticatedUser {}
/// class AuthFuture {
///   final FutureOr<AuthenticatedUser?> futureOr;
///   AuthFuture(this.futureOr);
/// }
///
/// var loginState = StateKey('login');
/// var authenticatingState = StateKey('authenticating');
///
/// var authenticatingChannel = EntryChannel<SubmitCredentials>(authenticatingState);
///
/// AuthFuture _login(SubmitCredentials creds) {
///   // ...Perform authentication
///   return AuthFuture(Future.value(AuthenticatedUser()));
/// }
/// var treeBuilder = StateTreeBuilder(initialChild: loginState);
///
/// treeBuilder.state(loginState, (b) {
///   b.onMessage<SubmitCredentials>((b) {
///     // Provide a SubmitCredentials value when entering authenticating state
///     b.enterChannel(authenticatingChannel, (ctx) => ctx.message);
///   });
/// });
///
/// treeBuilder.state(authenticatingState, (b) {
///   b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
///     // The context argument provides access to the SubmitCredentials value
///     b.post<AuthFuture>(getMessage: (ctx) => _login(ctx.context));
///   });
/// });
class EntryChannel<P> {
  /// The state to enter for this channel.
  final StateKey to;

  /// A descriptive label for this channel.
  final String? label;

  /// Constructs a channel for the [to] state.
  const EntryChannel(this.to, {this.label});

  /// Creates an [InitialData] that produces its value by calling [initialValue] with the payload
  /// provided when entering the state through this channel.
  ///
  /// ```dart
  /// var s1 = StateKey('state1');
  /// var s2 = DataStateKey<S2Data>('state2');
  /// var s2Channel = Channel<String>(s2);
  /// class S2Data {
  ///   String value = '';
  /// }
  /// var builder = StateTreeBuilder(initialChild: parentState);
  ///
  /// builder.state(s1, (b) {
  ///   b.onMessageValue('go', (b) => b.enterChannel(s2Channel, (msgCtx, msg) => 'Hi!'));
  /// });
  ///
  /// builder.dataState<S2Data>(
  ///   s2,
  ///   channel.initialData((payload) => S2Data()..value = payload),
  ///   (b) {
  ///     b.onEnter((b) {
  ///       // Will print 'Hi!'
  ///       b.run((transCtx, data) => print(data.value));
  ///     });
  ///   });
  /// ```
  InitialData<D> initialData<D>(D Function(P payload) initialValue) {
    return InitialData.run((transCtx) {
      try {
        return initialValue(transCtx.payloadOrThrow<P>());
      } catch (e) {
        throw StateError('Failed to obtain inital data of type $D for '
            'channel ${label != null ? '"$label" ' : ''}'
            'to state $to: $e');
      }
    });
  }

  /// Creates an [InitialData] that produces its initial value by calling the [initialValue]
  /// function with a value of type [DAnc], obtained from the ancestor state identified by
  /// [ancestorKey] and the payload value of this channel.
  InitialData<D> initialDataFromAncestor<D, DAnc>(
    DataStateKey<DAnc> ancestorKey,
    D Function(DAnc ancestorData, P payload) initialValue,
  ) {
    return InitialData.run((transCtx) {
      try {
        return initialValue(
          transCtx.data(ancestorKey).value,
          transCtx.payloadOrThrow<P>(),
        );
      } catch (e) {
        throw StateError('Failed to obtain inital data of type $D for '
            'channel ${label != null ? '"$label" ' : ''}'
            'to state $to: $e');
      }
    });
  }
}

enum NodeType { root, interior, leaf }

abstract class _StateBuilder {
  final StateKey key;
  final bool _isFinal;
  final List<StateKey> _children = [];
  final Logger _log;
  final InitialChild? _initialChild;
  final Type? _dataType;
  final StateDataCodec<dynamic>? _codec;
  final List<TreeStateFilter> _filters;
  final Map<String, Object> _metadata;
  StateKey? _parent;

  // Key is either a Type object representing message type or a message value
  final Map<Object, MessageHandlerDescriptor<void>> _messageHandlerMap = {};
  // 'Open-coded' message handler. This is mutually exclusive with _messageHandlerMap
  MessageHandler? _messageHandler;
  // Builder for onExit handler. This is mutually exclusive with _onExitHandler
  TransitionHandlerDescriptor<void>? _onExit;
  // 'Open-coded' onExit handler. This is mutually exclusive with _onExit
  TransitionHandler? _onExitHandler;
  // Builder for onEnter handler. This is mutually exclusive with _onEnterHandler
  TransitionHandlerDescriptor<void>? _onEnter;
  // 'Open-coded' onEnter handler. This is mutually exclusive with _onEnter
  TransitionHandler? _onEnterHandler;

  _StateBuilder._(
    this.key,
    this._isFinal,
    this._dataType,
    this._codec,
    this._log,
    this._parent,
    this._initialChild,
    List<TreeStateFilter>? filters,
    Map<String, Object>? metadata,
  )   : _metadata = metadata ?? {},
        _filters = filters ?? [];

  NodeType get nodeType {
    return switch (this) {
      _ when _parent == null => NodeType.root,
      _ when _children.isEmpty => NodeType.leaf,
      _ => NodeType.interior
    };
  }

  TreeNodeInfo toTreeNodeInfo(
    _StateBuilder Function(StateKey) getChildBuilder,
    TreeNodeInfo? parent,
  ) {
    return switch (nodeType) {
      NodeType.root => _toRootNodeInfo(getChildBuilder),
      NodeType.interior => _toInteriorNodeInfo(getChildBuilder, parent!),
      NodeType.leaf => _toLeafNodeInfo(parent!),
    };
  }

  LeafNodeInfo _toLeafNodeInfo(TreeNodeInfo parent) {
    return LeafNodeInfo(
      key,
      (_) => _createState(),
      parent: parent,
      dataCodec: _codec,
      filters: _filters,
      metadata: _metadata,
      isFinalState: _isFinal,
    );
  }

  RootNodeInfo _toRootNodeInfo(
    _StateBuilder Function(StateKey) getChildBuilder,
  ) {
    List<TreeNodeInfo> children = [];

    var nodeInfo = RootNodeInfo(
      key,
      (_) => _createState(),
      children: children,
      initialChild: _initialChild!.call,
      dataCodec: _codec,
      filters: _filters,
      metadata: _metadata,
    );

    children.addAll(_children
        .map(getChildBuilder)
        .map((sb) => sb.toTreeNodeInfo(getChildBuilder, nodeInfo)));

    return nodeInfo;
  }

  InteriorNodeInfo _toInteriorNodeInfo(
    _StateBuilder Function(StateKey) getChildBuilder,
    TreeNodeInfo parent,
  ) {
    List<TreeNodeInfo> children = [];

    var nodeInfo = InteriorNodeInfo(
      key,
      (_) => _createState(),
      parent: parent,
      children: children,
      initialChild: _initialChild!.call,
      dataCodec: _codec,
      filters: _filters,
      metadata: _metadata,
    );

    children.addAll(_children
        .map(getChildBuilder)
        .map((sb) => sb.toTreeNodeInfo(getChildBuilder, nodeInfo)));

    return nodeInfo;
  }

  bool get _hasStateData => _dataType != null;

  StateBuilderExtensionInfo _getExtensionInfo() =>
      StateBuilderExtensionInfo(key, _metadata, _filters);

  Iterable<MessageHandlerInfo> _getHandlerInfos() =>
      _messageHandlerMap.values.map((e) => e.info);

  void _addChild(_StateBuilder child) {
    child._parent = key;
    _children.add(child.key);
  }

  TreeState _createState() {
    return DelegatingTreeState(
      onMessage: _createMessageHandler(),
      onEnter: _createOnEnter(),
      onExit: _createOnExit(),
    );
  }

  MessageHandler _createMessageHandler() {
    if (_messageHandler != null) {
      return _messageHandler!;
    }

    final handlerMap = HashMap.fromEntries(
      _messageHandlerMap.entries
          .map((e) => MapEntry(e.key, e.value.makeHandler())),
    );

    return (MessageContext msgCtx) {
      var msg = msgCtx.message;
      // Note that if message handlers were registered by message type, then the runtime type of
      // a message must exactly match the registered type. That is, a message cannot be a subclass
      // of the registered type. Can we do better?
      var handler = handlerMap[msg] ?? handlerMap[msg.runtimeType];
      return handler != null ? handler(msgCtx) : msgCtx.unhandled();
    };
  }

  TransitionHandler _createOnEnter() {
    final onEnterHandler = _onEnterHandler;
    final onEnterDescriptor = _onEnter;
    if (onEnterHandler != null) {
      return onEnterHandler;
    } else if (onEnterDescriptor != null) {
      return onEnterDescriptor.makeHandler();
    }
    return emptyTransitionHandler;
  }

  TransitionHandler _createOnExit() {
    final onExitHandler = _onExitHandler;
    final onExitDescriptor = _onExit;
    if (onExitHandler != null) {
      return onExitHandler;
    } else if (onExitDescriptor != null) {
      return onExitDescriptor.makeHandler();
    }
    return emptyTransitionHandler;
  }

  void _makeVoidTransitionContext(TransitionContext ctx) {}
  void _makeVoidMessageContext(MessageContext ctx) {}
}

/// Provides methods for describing the behavior of a state, carrying state data of type [D], when
/// is entered. [D] may be `void` if the state does not have any associated state data.
abstract class EnterStateBuilder<D> {
  /// Handles all entry transitions with the [handler] function.
  void handleOnEnter(TransitionHandler handler, {String? label});

  /// Describes how transitions to this state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to describe
  /// the behavior of the entry transition.
  void onEnter(void Function(TransitionHandlerBuilder<D, void>) build);

  /// Describes how transitions to this state should be handled.
  ///
  /// This method can be used when the entry handler requires access to state data of type [D2] from
  /// an ancestor state.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to
  /// describe the behavior of the exit transition.
  void onEnterWithData<D2>(
    DataStateKey<D2> ancestorKey,
    void Function(TransitionHandlerBuilder<D, D2>) build,
  );

  /// Describes how transition to this state through [channel] should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used
  /// to describe the behavior of the entry transition.
  void onEnterFromChannel<P>(
    EntryChannel<P> channel,
    void Function(TransitionHandlerBuilder<D, P>) build,
  );
}

/// Provides methods for describing the behavior of a state carrying state data of type [D]. [D] may
/// be `void` if the state does not have any associated state data.
class StateBuilder<D> extends _StateBuilder implements EnterStateBuilder<D> {
  final InitialData<D> _typedInitialData;

  StateBuilder._(
    StateKey key,
    this._typedInitialData,
    Logger log,
    StateKey? parent,
    InitialChild? initialChild, {
    required bool isFinal,
    StateDataCodec<dynamic>? codec,
    List<TreeStateFilter>? filters,
    Map<String, Object>? metadata,
  }) : super._(
          key,
          isFinal,
          _isEmptyDataType<D>() ? null : D,
          codec,
          log,
          parent,
          initialChild,
          filters,
          metadata,
        );

  @override
  void onEnter(
    void Function(TransitionHandlerBuilder<D, void>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, void>._(
        key, _log, _makeVoidTransitionContext);
    build(builder);
    _onEnter = builder._descriptor;
  }

  @override
  void onEnterWithData<D2>(
    DataStateKey<D2> ancestorKey,
    void Function(TransitionHandlerBuilder<D, D2>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, D2>._(
        key, _log, (transCtx) => transCtx.data(ancestorKey).value);
    build(builder);
    _onEnter = builder._descriptor;
  }

  @override
  void onEnterFromChannel<P>(
    EntryChannel<P> channel,
    void Function(TransitionHandlerBuilder<D, P>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, P>._(
      key,
      _log,
      (transCtx) {
        try {
          return transCtx.payloadOrThrow<P>();
        } catch (e) {
          throw StateError('Failed to enter channel '
              '${channel.label != null ? '"${channel.label}" ' : ''}'
              'to state ${channel.to}: $e');
        }
      },
    );
    build(builder);
    _onEnter = builder._descriptor;
  }

  /// Handles all messages with the [handler] function.
  void handleOnMessage(MessageHandler handler) {
    _messageHandler = handler;
  }

  @override
  void handleOnEnter(TransitionHandler handler, {String? label}) {
    _onEnter = TransitionHandlerDescriptor.ofHandler(handler, label);
  }

  /// Handles all entry transitions with the [handler] function.
  void handleOnExit(TransitionHandler handler, {String? label}) {
    _onExit = TransitionHandlerDescriptor.ofHandler(handler, label);
  }

  /// Describes how messages of type [M] should be handled by this state.
  ///
  /// The [build] function is called with a [MessageHandlerBuilder] that can be used to describe
  /// the behavior of the message handler.
  void onMessage<M>(void Function(MessageHandlerBuilder<M, D, void> b) build,
      {M? message}) {
    var builder = MessageHandlerBuilder<M, D, void>(
        key, _makeVoidMessageContext, _log, null);
    build(builder);
    if (builder.descriptor != null) {
      var messageKey = message ?? M;
      _messageHandlerMap[messageKey] = builder.descriptor!;
    }
  }

  /// Describes how messages of type [M] should be handled by this state, when provided ancestor
  /// state data of type [D2].
  ///
  /// This method can be used when the message handler for a state requires access to state data
  /// from one of its ancestor states.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to
  /// describe the behavior of the exit transition.
  void onMessageWithData<M, D2>(DataStateKey<D2> ancestorKey,
      void Function(MessageHandlerBuilder<M, D, D2> b) build) {
    var builder = MessageHandlerBuilder<M, D, D2>(
      key,
      (msgCtx) => msgCtx.data(ancestorKey).value,
      _log,
      null,
    );
    build(builder);
    if (builder.descriptor != null) {
      _messageHandlerMap[M] = builder.descriptor!;
    }
  }

  /// Describes how a message value of type [M] should be handled by this state.
  ///
  /// The [build] function is called with a [MessageHandlerBuilder] that can be used to describe
  /// the behavior of the message handler.
  void onMessageValue<M>(
    M message,
    void Function(MessageHandlerBuilder<M, D, void> b) build, {
    String? messageName,
  }) {
    messageName = _getMessageName(messageName, message as Object);
    var builder = MessageHandlerBuilder<M, D, void>(
        key, _makeVoidMessageContext, _log, messageName);
    build(builder);
    if (builder.descriptor != null) {
      _messageHandlerMap[message] = builder.descriptor!;
    }
  }

  /// Describes how transitions from this state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to describe
  /// the behavior of the exit transition.
  void onExit(
    void Function(TransitionHandlerBuilder<D, void>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, void>._(
        key, _log, _makeVoidTransitionContext);
    build(builder);
    _onExit = builder._descriptor;
  }

  /// Describes how transitions from this state should be handled.
  ///
  /// This method can be used when the exit handler requires access to state data of type [D2] from
  /// an ancestor state.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to
  /// describe the behavior of the exit transition.
  void onExitWithData<D2>(
    DataStateKey<D2> ancestorKey,
    void Function(TransitionHandlerBuilder<D, D2>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, D2>._(
        key, _log, (transCtx) => transCtx.data(ancestorKey).value);
    build(builder);
    _onExit = builder._descriptor;
  }

  @override
  TreeState _createState() {
    return DelegatingDataTreeState<D>(
      _typedInitialData.call,
      onMessage: _createMessageHandler(),
      onEnter: _createOnEnter(),
      onExit: _createOnExit(),
      onDispose: emptyDispose,
    );
  }

  static bool _isEmptyDataType<D>() {
    return TypeLiteral<D>().type == TypeLiteral<void>().type;
  }

  static String? _getMessageName(String? messageName, Object? message) {
    messageName = messageName ?? message?.toString();
    if (message != null && isEnumValue(message)) {
      messageName = describeEnum(message);
    }
    return messageName;
  }
}

/// Provides methods for describing the transition from a [DeclarativeStateTreeBuilder.machineState] that
/// occurs when the nested state machine completes.
class MachineStateBuilder extends _StateBuilder {
  final InitialMachine _initialMachine;
  final bool Function(Transition transition)? _isDone;
  final _currentStateRef = Ref<CurrentState?>(null);
  MessageHandlerDescriptor<CurrentState>? _doneDescriptor;
  MessageHandlerDescriptor<void>? _disposedDescriptor;

  MachineStateBuilder(
    DataStateKey<MachineTreeStateData> key,
    this._initialMachine,
    this._isDone,
    Logger log,
    StateKey? parent, {
    required bool isFinal,
    StateDataCodec<dynamic>? codec,
    Map<String, Object>? metadata,
  }) : super._(
          key,
          isFinal,
          MachineTreeStateData,
          codec,
          log,
          parent,
          null,
          // Machine states do not support filters, they might disrupt the lifecycle
          // of the nested machine
          [],
          metadata,
        );

  void onMachineDone(
    void Function(MachineDoneHandlerBuilder<CurrentState> builder) buildHandler,
  ) {
    var builder = MachineDoneHandlerBuilder<CurrentState>._(
      key,
      (_) => _currentStateRef.value!,
      _log,
      'Machine Done',
    );
    buildHandler(builder);
    _doneDescriptor = builder.descriptor;
  }

  void onMachineDisposed(
    void Function(MachineDoneHandlerBuilder<void> builder) buildHandler,
  ) {
    var builder = MachineDoneHandlerBuilder<void>._(
      key,
      (_) {},
      _log,
      'Machine Disposed',
    );
    buildHandler(builder);
    _disposedDescriptor = builder.descriptor;
  }

  @override
  Iterable<MessageHandlerInfo> _getHandlerInfos() =>
      super._getHandlerInfos().followedBy([
            _doneDescriptor?.info,
            _disposedDescriptor?.info
          ].where((i) => i != null).cast<MessageHandlerInfo>());

  @override
  TreeState _createState() {
    var doneDescriptor = _doneDescriptor;
    if (doneDescriptor == null) {
      throw StateError(
          "Nested machine state '$key' does not have a done handler. Make sure to call onMachineDone.");
    }

    return MachineTreeState(
      _initialMachine,
      (currentState) {
        _currentStateRef.value = currentState;
        return doneDescriptor.makeHandler();
      },
      _log,
      _isDone,
      _disposedDescriptor?.makeHandler(),
    );
  }
}
