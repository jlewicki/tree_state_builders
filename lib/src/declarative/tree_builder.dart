import 'package:logging/logging.dart';
import 'package:tree_state_builders/declarative.dart';
import 'package:tree_state_builders/tree_state_machine.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// A state builder callback that adds no behavior to a state.
void emptyState(StateBuilder builder) {}

/// Provides methods for describing the states in a state tree.
class DeclarativeStateTreeBuilder {
  final StateKey _rootKey;
  final Map<StateKey, TreeStateBuilder> _stateBuilders = {};
  late final Logger _log = Logger(
    'tree_state_machine.StateTreeBuilder${logName != null ? '.${logName!}' : ''}',
  );

  DeclarativeStateTreeBuilder._(
    this._rootKey,
    this.label,
    String? logName,
  ) : logName = logName ?? label;

  factory DeclarativeStateTreeBuilder({
    required StateKey initialChild,
    String? label,
    String? logName,
  }) {
    var b = DeclarativeStateTreeBuilder._(defaultRootKey, label, logName);
    b.state(
      defaultRootKey,
      emptyState,
      initialChild: InitialChild(initialChild),
    );
    return b;
  }

  /// The key identifying the root state that is implicitly added to a state tree, if the
  /// [DeclarativeStateTreeBuilder.new] constructor is used.
  static const StateKey defaultRootKey = StateKey('<_RootState_>');

  /// An optional descriptive label for this state tree, for diagnostic purposes.
  final String? label;

  /// An optional name will be used as a suffix when naming the [Logger] used by this builder.
  ///
  /// This can be used to help correlate log messages with specific state trees when examining log
  /// output.
  final String? logName;

  /// Identifies the root state of the state tree.
  StateKey get rootKey => _rootKey;

  /// Builds the state tree described by this builder, and returns the root node of the tree.
  TreeNode build(TreeBuildContext buildContext) {
    var rootBuilder = _getStateBuilder(_rootKey);
    return _buildTreeNode(buildContext, rootBuilder);
  }

  void state(
    StateKey stateKey,
    void Function(StateBuilder builder) build, {
    StateKey? parent,
    InitialChild? initialChild,
  }) {
    var builder = StateBuilder(
      stateKey,
      parent: parent,
      isFinal: false,
      log: _log,
    );
    build(builder);
    _addState(builder);
    // return StateExtensionBuilder._(builder);
  }

  void _addState(TreeStateBuilder builder) {
    if (_stateBuilders.containsKey(builder.stateKey)) {
      throw StateError(
          "State '${builder.stateKey}' has already been configured.");
    }
    _stateBuilders[builder.stateKey] = builder;
  }

  TreeNode _buildTreeNode(
    TreeBuildContext context,
    TreeStateBuilder stateBuilder,
  ) {
    var nodeBuildInfo = stateBuilder.toTreeNodeBuildInfo(_makeChildNodeBuilder);
    return switch (stateBuilder.stateInfo.stateType) {
      TreeStateType.root => context.buildRoot(nodeBuildInfo),
      TreeStateType.interior => context.buildInterior(nodeBuildInfo),
      TreeStateType.leaf => context.buildLeaf(nodeBuildInfo),
    };
  }

  TreeNodeBuilder _makeChildNodeBuilder(StateKey childStateKey) {
    var childBuilder = _getStateBuilder(childStateKey);
    return (childCtx) => _buildTreeNode(childCtx, childBuilder);
  }

  TreeStateBuilder _getStateBuilder(StateKey key) {
    var stateBuilder = _stateBuilders[key];
    assert(stateBuilder != null);
    return stateBuilder!;
  }
}

/// Describes the initial child state of a parent state.
///
/// Because the current state in a tree state machine is always a leaf state, when a parent state is
/// entered, one of its children must immediately be entered as well. The specific child state that
/// is entered is called the initial child of the parent state, and is determined by a [GetInitialChild]
/// function that is run on entering the parent state.
///
/// [InitialChild] allows configuration of [GetInitialChild] as a state is being defined.
/// ```dart
/// var parentState = StateKey('p');
/// var childState1 = StateKey('c1');
/// var childState2 = StateKey('c2');
/// var builder = StateTreeBuilder(initialChild: parentState);
///
/// // Enter childState2 when parentState is entered
/// builder.state(parentState, emptyState, initialChild: InitialChild(childState2));
/// builder.state(childState1, emptyState, parent: parentState);
/// builder.state(childState2, emptyState, parent: parentState);
/// ```
///
class InitialChild {
  final StateKey? _initialChild;
  final GetInitialChild _getInitialChild;
  InitialChild._(this._getInitialChild, this._initialChild);

  /// Constructs an [InitialChild] indicating that the state identified by [initialChild] should be entered.
  factory InitialChild(StateKey initialChild) {
    return InitialChild._((_) => initialChild, initialChild);
  }

  /// Constructs an [InitialChild] that will run the [getInitialChild] function when the state is
  /// entered in order to determine the initial child,
  ///
  /// Because the behavior of [getInitialChild] is opaque to a [StateTreeFormatter] when
  /// [DeclarativeStateTreeBuilder.format] is called, the graph description produced by the formatter may not
  /// be particularly useful. This method is best avoided if the formatting feature is important to you.
  factory InitialChild.run(GetInitialChild getInitialChild) {
    return InitialChild._(getInitialChild, null);
  }

  /// Returns the key of the child state that should be entered.
  StateKey call(TransitionContext transCtx) => _getInitialChild(transCtx);
}

/// Describes the initial value for a [DeclarativeStateTreeBuilder.dataState] that carries a value of type [D].
class InitialData<D> {
  /// The type of [D].
  final Type dataType = D;
  final D Function(TransitionContext) _initialValue;

  InitialData._(this._initialValue);

  /// Initial data for a 'regular' state (that is, not a data state).
  static final InitialData<void> _empty = InitialData(() {});

  /// Creates the initial data value.
  D call(TransitionContext transCtx) => _initialValue(transCtx);

  /// Creates an [InitialData] that will call the [create] function to obtain the initial data
  /// value. The function is called each time the data state is entered.
  factory InitialData(D Function() create) {
    return InitialData._((_) => create());
  }

  /// Creates an [InitialData] that will call the [create] function, passing the [TransitionContext]
  /// for the transition in progress, to obtain the initial data value. The function is called each
  /// time the data state is entered.
  factory InitialData.run(D Function(TransitionContext) create) {
    return InitialData._(create);
  }

  /// Creates an [InitialData] that produces its value by calling [initialValue] with the payload
  /// provided when entering the state through [channel].
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
  ///   InitialData.fromChannel(channel, (payload) => S2Data()..value = payload),
  ///   (b) {
  ///     b.onEnter((b) {
  ///       // Will print 'Hi!'
  ///       b.run((transCtx, data) => print(data.value));
  ///     });
  ///   });
  /// ```
  // static InitialData<D> fromChannel<D, P>(
  //     Channel<P> channel, D Function(P payload) initialValue) {
  //   return InitialData._((transCtx) {
  //     try {
  //       return initialValue(transCtx.payloadOrThrow<P>());
  //     } catch (e) {
  //       throw StateError('Failed to obtain inital data of type $D for '
  //           'channel ${channel.label != null ? '"${channel.label}" ' : ''}'
  //           'to state ${channel.to}: $e');
  //     }
  //   });
  // }

  /// Creates an [InitialData] that produces its initial value by calling [initialValue] with
  /// a value of type [DAncestor], obtained by from an ancestor state in the state tree.
  ///
  /// ```dart
  /// class ParentData {
  ///   String value = '';
  ///   ParentData(this.value);
  /// }
  /// var parentState = DataStateKey<ParentData>('parent');
  /// var childState = DataStateKey<int>('child');
  /// var builder = StateTreeBuilder(initialChild: parentState);
  ///
  /// builder.dataState<ParentData>(
  ///   parentState,
  ///   InitialData.value(ParentData('parent value')),
  ///   (_) {},
  ///   initialChild: childState);
  ///
  /// builder.dataState<int>(
  ///   childState,
  ///   // Initialize the state data for the child state from the state data of
  ///   // the parent state
  ///   InitialData.fromAncestor((ParentData ancestorData) => ancestorData.length),
  ///   (_) {},
  ///   parent: parentState
  /// );
  /// ```
  static InitialData<D> fromAncestor<D, DAncestor>(
      D Function(DAncestor ancData) initialValue) {
    return InitialData._(
        (ctx) => initialValue(ctx.dataValueOrThrow<DAncestor>()));
  }

  /// Creates an [InitialData] that produces its initial value by calling [initialValue] with
  /// a value of type [DAncestor], obtained by from an ancestor state in the state tree, and the
  /// payload value of [channel].
  // static InitialData<D> fromChannelAndAncestor<D, DAncestor, P>(
  //   Channel<P> channel,
  //   D Function(DAncestor parentData, P payload) initialValue,
  // ) {
  //   return InitialData._(
  //     (ctx) => initialValue(
  //         ctx.dataValueOrThrow<DAncestor>(), ctx.payloadOrThrow<P>()),
  //   );
  // }
}
