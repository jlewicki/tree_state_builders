import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:tree_state_builders/declarative.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'fixture/fixture_data.dart';

final Matcher throwsStateTreeDefinitionError =
    throwsA(isA<StateTreeDefinitionError>());

void main() {
  group('StateTreeBuilder', () {
    final rootState = StateKey('r');
    final state1 = StateKey('s1');
    final state2 = StateKey('s2');
    final state3 = StateKey('s3');

    group('factory', () {
      test('should create implicit root state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState);
        var rootNode = sb.createRootNodeInfo();
        expect(DeclarativeStateTreeBuilder.defaultRootKey, rootNode.key);
        expect(rootNode.children.length, 1);
        expect(rootNode.children[0].key, state1);
        expect(
          rootNode.children.first.parent()!.key,
          DeclarativeStateTreeBuilder.defaultRootKey,
        );
        expect(
          rootNode.children.first.parent()!.key,
          DeclarativeStateTreeBuilder.defaultRootKey,
        );
        expect(sb.rootKey, DeclarativeStateTreeBuilder.defaultRootKey);
      });
    });

    group('factory.withRoot', () {
      test('should create explicit root state', () {
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.state(state1, emptyState);
        var rootNode = sb.createRootNodeInfo();
        expect(rootNode.key, rootState);
        expect(rootNode.children.length, 1);
        expect(rootNode.children[0].key, state1);
        expect(rootNode.children.first.parent()?.key, rootState);
        expect(rootState, sb.rootKey);
      });
    });

    group('factory.withDataRoot', () {
      final rootState = DataStateKey<int>('root');
      test('should create explicit root state', () {
        var sb = DeclarativeStateTreeBuilder.withDataRoot<int>(
          rootState,
          InitialData(() => 1),
          emptyState,
          InitialChild(state1),
        );
        sb.state(state1, emptyState);
        var rootNode = sb.createRootNodeInfo();
        expect(rootNode.key, rootState);
        expect(rootNode.children.length, 1);
        expect(rootNode.children[0].key, state1);
        expect(rootNode.children.first.parent()?.key, rootState);
        expect(rootState, sb.rootKey);
      });
    });

    group('state', () {
      test('should create a leaf state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: null);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectLeafNode(state1Node);
      });

      test('should create a leaf state (rooted)', () {
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.state(state1, emptyState, initialChild: null);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectLeafNode(state1Node);
      });

      test('should create an interior state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState, parent: state1);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectInteriorNode(state1Node, [state2]);
      });

      test('should create an interior state (rooted)', () {
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState, parent: state1);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectInteriorNode(state1Node, [state2]);
      });

      test('should throw if state is defined more than once', () {
        var state1 = StateKey('s1');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: null);
        expect(() => sb.state(state1, emptyState, initialChild: null),
            throwsStateTreeDefinitionError);
      });
    });

    group('dataState', () {
      test('should create a leaf state', () {
        final state1 = DataStateKey<int>('state1');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.dataState<int>(state1, InitialData(() => 1), emptyState,
            initialChild: null);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectLeafNode(state1Node);
      });

      test('should create a leaf state (rooted)', () {
        final state1 = DataStateKey<int>('state1');
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.dataState<int>(state1, InitialData(() => 1), emptyState,
            initialChild: null);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectLeafNode(state1Node);
      });

      test('should create an interior state', () {
        final state1 = DataStateKey<String>('state1');
        final state2 = DataStateKey<String>('state2');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.dataState<String>(state1, InitialData(() => ''), emptyState,
            initialChild: InitialChild(state2));
        sb.dataState<String>(state2, InitialData(() => ''), emptyState,
            parent: state1);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectInteriorNode(state1Node, [state2]);
      });

      test('should throw if state is defined more than once', () {
        final state1 = DataStateKey<int>('state1');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.dataState<int>(state1, InitialData(() => 1), emptyState,
            initialChild: null);
        expect(
          () => sb.dataState<int>(state1, InitialData(() => 1), emptyState,
              initialChild: null),
          throwsStateTreeDefinitionError,
        );
      });
    });

    group('finalState', () {
      test('should create a final leaf state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalState(state1, emptyFinalState);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectLeafNode(state1Node, isFinal: true);
      });

      test('should throw if state is defined more than once', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalState(state1, emptyFinalState);
        expect(
          () => sb.finalState(state1, emptyFinalState),
          throwsStateTreeDefinitionError,
        );
      });
    });

    group('finalDataState', () {
      final state1 = DataStateKey<int>('state1');
      test('should create a final data leaf state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalDataState<int>(state1, InitialData(() => 1), emptyFinalState);
        var rootNode = sb.createRootNodeInfo();
        var state1Node = rootNode.children.first;
        expect(state1Node.key, state1);
        expectLeafNode(state1Node, isFinal: true);
      });

      test('should throw if state is defined more than once', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalDataState<int>(state1, InitialData(() => 1), emptyFinalState);
        expect(
          () => sb.finalDataState<int>(
              state1, InitialData(() => 1), emptyFinalState),
          throwsStateTreeDefinitionError,
        );
      });
    });

    group('build', () {
      test('should throw if a parent state is missing initial child', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState);
        sb.state(state2, emptyState, parent: state1);
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child is not defined', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child has no parent', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        sb.state(state3, emptyState);
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child has wrong parent', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        sb.state(state3, emptyState, parent: state4);
        sb.state(state4, emptyState, initialChild: InitialChild(state3));
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child of implicit root has a parent', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state2);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        sb.state(state3, emptyState, parent: state4);
        sb.state(state4, emptyState, initialChild: InitialChild(state3));
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if there is a transition to an unknown state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, (b) {
          b.onMessage<String>((b) => b.goTo(state3));
        });
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if parent state is referenced but not defined', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState, parent: state3);
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial state is referenced but not defined', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state3);
        sb.state(state1, emptyState);
        sb.state(state2, emptyState);
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if circular parent-child references', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState,
            parent: state1, initialChild: InitialChild(state3));
        sb.state(state3, emptyState, parent: state1);
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });

      test('should throw if a parent state is a final state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalState(state1, emptyFinalState);
        sb.state(state2, emptyState, parent: state1);
        expect(() => sb.createRootNodeInfo(), throwsStateTreeDefinitionError);
      });
    });
  });
}

void expectLeafNode(TreeNodeInfo node, {bool isFinal = false}) {
  expect(node, isA<LeafNodeInfo>());
  expect((node as LeafNodeInfo).isFinalState, isFinal ? isTrue : isFalse);
  expect(node.children().isEmpty, isTrue);
}

void expectInteriorNode(TreeNodeInfo node, List<StateKey> children) {
  expect(node, isA<InteriorNodeInfo>());
  expect(node.children().isNotEmpty, isTrue);
  expect(
      ListEquality<StateKey>().equals(
        node.children().map((e) => e.key).toList(),
        children,
      ),
      isTrue);
}
