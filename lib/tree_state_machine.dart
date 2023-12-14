// Hypothezies API changes to tree_state_machine package

import 'package:tree_state_machine/tree_state_machine.dart';

/// Provides a description of how a [TreeNode] should be built.
class TreeNodeBuildInfo {
  TreeNodeBuildInfo(
    this.key,
    this.createState, {
    this.initialChild,
    this.childBuilders = const [],
    this.codec,
    this.filters = const [],
    this.metadata = const {},
  });

  final StateKey key;
  final TreeStateCreator createState;
  final Iterable<TreeNodeBuilder> childBuilders;
  final GetInitialChild? initialChild;
  final StateDataCodec<dynamic>? codec;
  final List<TreeStateFilter> filters;
  final Map<String, Object> metadata;
}

/// Provides contextual information while a state tree is being constructed, and factory methods for
/// creating tree nodes.
///
/// This interface is infrastructure, and is not intended to be called by application code.
class TreeBuildContext {
  /// Map of nodes that have been built.
  final Map<StateKey, TreeNode> _nodes = {};

  TreeNode buildRoot(
    TreeNodeBuildInfo nodeBuildInfo,
  ) {
    return TreeNode(nodeBuildInfo.key);
  }

  TreeNode buildInterior(
    TreeNodeBuildInfo nodeBuildInfo,
  ) {
    return TreeNode(nodeBuildInfo.key);
  }

  TreeNode buildLeaf(
    TreeNodeBuildInfo nodeBuildInfo,
  ) {
    return TreeNode(nodeBuildInfo.key);
  }

  void _addNode(TreeNode node) {
    if (_nodes.containsKey(node.key)) {
      final msg =
          'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    _nodes[node.key] = node;
  }
}

/// This kind of wants to be internal to the library
class TreeNode {
  TreeNode(this.key);
  final StateKey key;
}

class TreeState {}

typedef TreeStateCreator = TreeState Function(StateKey key);

typedef TreeNodeBuilder = TreeNode Function(TreeBuildContext buildContext);

class TreeStateMachine {
  TreeStateMachine(TreeNodeBuilder rootNodeBuilder,
      {TreeBuildContext? buildContext});
}
