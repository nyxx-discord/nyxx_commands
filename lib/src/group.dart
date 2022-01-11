//  Copyright 2021 Abitofevrything and others.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'checks.dart';
import 'command.dart';
import 'commands.dart';
import 'context.dart';
import 'errors.dart';
import 'view.dart';

/// A [Group] is a collection of commands. This mixin implements that functionality.
///
/// All [Group]s, [Command]s and [CommandsPlugin]s use this mixin to enable nesting and registration
/// of commands.
mixin GroupMixin {
  /// A mapping of child names to children.
  ///
  /// Used for easier lookup of children based on both [name] and [aliases].
  final Map<String, GroupMixin> childrenMap = {};

  /// An iterable of all this groups children.
  ///
  /// Each child is only present once, and in no particular order.
  Iterable<GroupMixin> get children => Set.of(childrenMap.values);

  /// The parent of this group, if any.
  GroupMixin? get parent => _parent;

  GroupMixin? _parent;

  /// The name of this group.
  String get name;

  /// A list of aliases that can also be used to refer to this group.
  Iterable<String> get aliases;

  /// A description of what this group represents.
  String get description;

  @protected
  // ignore: public_member_api_docs
  final StreamController<Context> preCallController = StreamController.broadcast();

  @protected
  // ignore: public_member_api_docs
  final StreamController<Context> postCallController = StreamController.broadcast();

  /// A [Stream] of [Context]s that emits after the checks have succeeded, but before
  /// [Command.execute] is called.
  late final Stream<Context> onPreCall = preCallController.stream;

  /// A [Stream] of [Context]s that emits after [Command.execute] has successfully been called (no
  /// exceptions were thrown).
  late final Stream<Context> onPostCall = postCallController.stream;

  final List<AbstractCheck> _checks = [];

  /// A list of functions that must return `true` for any descendant of this group to be executed.
  /// These are called before command invocation and can cause it to fail.
  ///
  /// If you only want to apply a check to a specific command and not all descendants, see
  /// [Command.singleChecks]
  Iterable<AbstractCheck> get checks => [...?_parent?.checks, ..._checks];

  /// The full name of this group.
  ///
  /// The full name of a group is its name appended to its parents [fullName].
  String get fullName =>
      (_parent == null || _parent is CommandsPlugin ? '' : _parent!.name + ' ') + name;

  /// The depth of this group.
  ///
  /// If this group is a root group, the depth will be 0.
  /// If not, it will be the number of ancestors this group has.
  int get depth => (_parent?.depth ?? -1) + 1;

  /// Whether this group contains any slash commands.
  ///
  /// These might not be direct children, and can be nested multiple layers for this method to
  /// return true.
  bool get hasSlashCommand {
    return children.any((child) {
      if (child is Command) {
        return child.type != CommandType.textOnly || child.hasSlashCommand;
      }
      return child.hasSlashCommand;
    });
  }

  final Logger _logger = Logger('Commands');

  /// Get a [Command] based off a [StringView].
  ///
  /// This is usually used to obtain the command being executed in a message, after the prefix has
  /// been skipped in the view.
  Command? getCommand(StringView view) {
    String name = view.getWord();

    if (childrenMap.containsKey(name)) {
      GroupMixin child = childrenMap[name]!;

      if (child is Command && child.type != CommandType.slashOnly) {
        Command? found = child.getCommand(view);

        if (found == null) {
          return child;
        }

        return found;
      } else {
        return child.getCommand(view);
      }
    }

    view.undo();
    return null;
  }

  /// Add a child to this group.
  ///
  /// If any of its name or aliases confict with already registered commands, a
  /// [CommandRegistrationError] is thrown.
  ///
  /// If [child] already has a parent, an [CommandRegistrationError] is thrown.
  void addCommand(GroupMixin command) {
    if (childrenMap.containsKey(command.name)) {
      throw CommandRegistrationError(
          'Command with name "$fullName ${command.name}" already exists');
    }

    for (final alias in command.aliases) {
      if (childrenMap.containsKey(alias)) {
        throw CommandRegistrationError('Command with alias "$fullName $alias" already exists');
      }
    }

    if (command._parent != null) {
      throw CommandRegistrationError('Cannot register command "${command.fullName}" again');
    }

    if (_parent != null) {
      _logger.warning('Registering commands to a group after it is registered might cause slash '
          'commands to have incomplete definitions');
    }

    command._parent = this;

    childrenMap[command.name] = command;
    for (final alias in command.aliases) {
      childrenMap[alias] = command;
    }

    command.onPreCall.listen(preCallController.add);
    command.onPostCall.listen(postCallController.add);
  }

  /// Add a child to this group.
  ///
  /// If any of its name or aliases confict with already registered commands, a
  /// [CommandRegistrationError] is thrown.
  ///
  /// If [child] already has a parent, an [CommandRegistrationError] is thrown.
  @Deprecated('Use addCommand() instead')
  void registerChild(GroupMixin child) => addCommand(child);

  /// Iterate over all the commands in this group and any subgroups.
  Iterable<Command> walkCommands() sync* {
    if (this is Command) {
      yield this as Command;
    }

    for (final child in children) {
      yield* child.walkCommands();
    }
  }

  /// Build the options for registering this group to the Discord API for slash commands.
  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands) {
    List<CommandOptionBuilder> options = [];

    for (final child in children) {
      if (child.hasSlashCommand) {
        options.add(CommandOptionBuilder(
          CommandOptionType.subCommandGroup,
          child.name,
          child.description,
          options: List.of(child.getOptions(commands)),
        ));
      } else if (child is Command && child.type != CommandType.textOnly) {
        options.add(CommandOptionBuilder(
          CommandOptionType.subCommand,
          child.name,
          child.description,
          options: List.of(child.getOptions(commands)),
        ));
      }
    }

    return options;
  }

  /// Add a check to this groups [checks].
  void check(AbstractCheck check) {
    _checks.add(check);

    for (final preCallHook in check.preCallHooks) {
      onPreCall.listen(preCallHook);
    }

    for (final postCallHook in check.postCallHooks) {
      onPostCall.listen(postCallHook);
    }
  }
}

/// A [Group] is a simple class that allows [GroupMixin]s to be instanciated.
///
/// This allows [GroupMixin] functionality to be used without the additional bloat of a [Command] or
/// [CommandsPlugin]
class Group with GroupMixin {
  @override
  String name;
  @override
  String description;
  @override
  Iterable<String> aliases;

  /// Construct a new [Group]
  Group(
    this.name,
    this.description, {
    this.aliases = const [],
    Iterable<GroupMixin> children = const [],
    Iterable<AbstractCheck> checks = const [],
  }) {
    if (!commandNameRegexp.hasMatch(name) || name != name.toLowerCase()) {
      throw CommandRegistrationError('Invalid group name "$name"');
    }

    for (final child in children) {
      addCommand(child);
    }

    for (final check in checks) {
      super.check(check);
    }
  }

  @override
  String toString() => 'Group[name="$name", fullName="$fullName"]';
}
