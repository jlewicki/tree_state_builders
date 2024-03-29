/// Provides support for defining state trees in a declarative fashion.
///
/// When defining state and their behavior with this library, [DeclarativeStateTreeBuilder] captures
/// a description of the resulting state tree that can be used to generate a diagram of the tree,
/// which may be useful for documentation purposes.
///
/// ```dart
/// class States {
///   static final locked = StateKey('locked');
///   static final unlocked = StateKey('unlocked');
/// }
///
/// var builder = DeclarativeStateTreeBuilder(initialChild: States.locked)
///   ..state(States.locked, (b) {
///     b.onMessageValue(Messages.insertCoin, (b) => b.goTo(States.unlocked));
///   })
///   ..state(States.unlocked, (b) {
///     b.onMessageValue(Messages.push, (b) => b.goTo(States.locked),
///         messageName: 'push');
///   });
///
///  var sb = StringBuffer();
///  declBuilder.format(sb, DotFormatter());
///  print(sb.toString());
/// ```
library declarative;

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'src/utility.dart';

import 'src/declarative/handlers/messages/message_handler_descriptor.dart';
import 'src/declarative/handlers/messages/go_to_descriptor.dart';
import 'src/declarative/handlers/messages/go_to_self_descriptor.dart';
import 'src/declarative/handlers/messages/stay_or_unhandled_descriptor.dart';
import 'src/declarative/handlers/messages/when_descriptor.dart';
import 'src/declarative/handlers/messages/when_result_descriptor.dart';

import 'src/declarative/handlers/transitions/transition_handler_descriptor.dart';
import 'src/declarative/handlers/transitions/update_data_descriptor.dart';
import 'src/declarative/handlers/transitions/when_result_descriptor.dart';
import 'src/declarative/handlers/transitions/when_descriptor.dart';
import 'src/declarative/handlers/transitions/run_descriptor.dart';
import 'src/declarative/handlers/transitions/post_descriptor.dart';
import 'src/declarative/handlers/transitions/schedule_descriptor.dart';

part 'src/declarative/tree_builder.dart';
part 'src/declarative/tree_formatters.dart';
part 'src/declarative/state_builder.dart';
part 'src/declarative/state_builder_extensions.dart';
part 'src/declarative/message_action_builder.dart';
part 'src/declarative/message_handler_builder.dart';
part 'src/declarative/transition_handler_builder.dart';
part 'src/declarative/handlers/messages/message_handler_context.dart';
part 'src/declarative/handlers/transitions/transition_handler_context.dart';



// To publish:
// dart pub publish --dry-run
// git tag -a vX.X.X -m "Publish vX.X.X"
// git push origin vX.X.X
// dart pub publish
//
// If you mess up
// git tag -d vX.X.X
// git push --delete origin vX.X.X
