import 'package:logging/logging.dart';
import 'package:tree_state_builders/declarative.dart';
import 'package:tree_state_builders/tree_state_machine.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

enum TreeStateType { root, interior, leaf }

/// Provides a description of how a tree state will be built.
///
/// This class is read-only, but not necessarily immutable.
abstract class StateBuildInfo {
  StateBuildInfo({
    required this.stateKey,
    required this.isFinal,
  });

  /// Unique identifier for this state in a state tree.
  final StateKey stateKey;

  /// Indicates if this is a final state
  final bool isFinal;

  /// Identifies the parent state of this state, or `null` if this is a root state.
  StateKey? get parent;

  /// Unmodifiable list of the the child states of this state. The list is empty if this is a leaf
  /// state.
  List<StateKey> get children;

  /// Identifies the type of state, relative to others in a state tree.
  TreeStateType get stateType {
    if (parent == null) return TreeStateType.root;
    if (children.isEmpty) return TreeStateType.leaf;
    return TreeStateType.interior;
  }
}

/// Provides update operations for [StateBuildInfo].
class _StateBuildInfo extends StateBuildInfo {
  _StateBuildInfo(
      {required super.stateKey,
      required super.isFinal,
      required StateKey? parent})
      : _parent = parent;

  /// Parent state of this state, if any
  StateKey? _parent;

  /// The children of of this state
  final _children = <StateKey>[];

  @override
  StateKey? get parent => _parent;

  @override
  late final List<StateKey> children = List.unmodifiable(_children);

  void _addChild(_StateBuildInfo child) {
    child._parent = stateKey;
    _children.add(child.stateKey);
  }
}

/// Provides a description of how a tree state should be built.
abstract class TreeStateBuilder {
  /// Identifies the state that will be built.
  StateKey get stateKey;

  /// Creates a [TreeNodeBuildInfo] describing how to build a [TreeNode], based on the description
  /// provided by this [TreeStateBuilder].
  TreeNodeBuildInfo toTreeNodeBuildInfo(
    TreeNodeBuilder Function(StateKey) getChildNodeBuilder,
  );

  /// Information describing how this state will be built.
  StateBuildInfo get stateInfo;
}

/// Provides information and methods that can be used to describe the behavior a state in a state tree.
class StateBuilder extends TreeStateBuilder {
  StateBuilder(
    this.stateKey, {
    StateKey? parent,
    bool isFinal = false,
    required Logger log,
  })  : _log = log,
        _stateInfo = _StateBuildInfo(
          stateKey: stateKey,
          isFinal: isFinal,
          parent: null,
        );

  @override
  final StateKey stateKey;

  @override
  StateBuildInfo get stateInfo => _stateInfo;

  final Logger _log;
  final _StateBuildInfo _stateInfo;

  @override
  TreeNodeBuildInfo toTreeNodeBuildInfo(
    TreeNodeBuilder Function(StateKey) getChildNodeBuilder,
  ) {
    return TreeNodeBuildInfo(
      stateKey,
      (key) => TreeState(),
    );
  }
}

/// Provides information and methods that can be used to describe the behavior a data state, with
/// state data of type [D], in a state tree.
class DataStateBuilder<D> extends TreeStateBuilder {
  DataStateBuilder(
    this.stateKey, {
    required this.initialData,
    bool isFinal = false,
    required Logger log,
  })  : _log = log,
        _stateInfo = _StateBuildInfo(
          stateKey: stateKey,
          isFinal: isFinal,
          parent: null,
        );

  @override
  final DataStateKey<D> stateKey;

  final InitialData<D> initialData;

  @override
  StateBuildInfo get stateInfo => _stateInfo;

  final _StateBuildInfo _stateInfo;

  final Logger _log;

  @override
  TreeNodeBuildInfo toTreeNodeBuildInfo(
    TreeNodeBuilder Function(StateKey) getChildNodeBuilder,
  ) {
    return TreeNodeBuildInfo(
      stateKey,
      (key) => TreeState(),
    );
  }
}
