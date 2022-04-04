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

import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../context/chat_context.dart';
import '../context/context.dart';
import '../errors.dart';
import '../util/view.dart';
import 'options.dart';

/// Represents an entity which can handle command callback hooks.
abstract class ICallHooked<T extends IContext> {
  /// A stream that emits contexts *before* the command callback is executed.
  ///
  /// This stream emits before the callback is executed, but after checks and argument parsing is
  /// complete.
  ///
  /// You might also be interested in:
  /// -[onPostCall], for listening to the end of a command execution.
  Stream<T> get onPreCall;

  /// A stream that emits contexts *after* the command callback is executed.
  ///
  /// You might also be interested in:
  /// - [onPreCall], for listening to the start of a command execution.
  Stream<T> get onPostCall;
}

/// Represents an entity that can handle checks.
///
/// See [AbstractCheck] for an explanation of checks.
abstract class IChecked {
  /// The checks that should be applied to this entity.
  ///
  /// Check are inherited, so this will include checks from any parent entities.
  Iterable<AbstractCheck> get checks;

  /// Add a check to this entity.
  ///
  /// You might also be interested in:
  /// - [ChatCommand.singleCheck], for registering checks that are not inherited.
  void check(AbstractCheck check);
}

/// Represents an entity that supports command options.
///
/// Command options can influence a command's behaviour and how it can be invoked. Options are
/// inherited.
abstract class IOptions {
  /// The options to use for this entity.
  CommandOptions get options;
}

/// Represents an entity that can be added as a child to a command group.
///
/// You might also be interested in:
/// - [ICommandGroup], the interface for groups that [ICommandRegisterable]s can be added to.
abstract class ICommandRegisterable<T extends IContext>
    implements ICallHooked<T>, IChecked, IOptions {
  /// The name of this child.
  ///
  /// Generally, this will have to obey [Discord's command naming restrictions](https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-naming)
  /// and be unique to this child.
  String get name;

  /// The parent of this child.
  ///
  /// Once a parent is added to a group, that group is considered to be this child's parent and this
  /// child cannot be added to any more groups. Attempting to do so will result in a
  /// [CommandsError].
  ICommandGroup<IContext>? get parent;

  /// Set the parent of this child. Should not be used unless you are implementing your own command
  /// group.
  set parent(ICommandGroup<IContext>? parent);

  /// Get the resolvec options for this child.
  ///
  /// Since [ICommandRegisterable] implements [IOptions], any class implementing this interface can
  /// provide options. However, since options are designed to be inherited, this getter provides a
  /// quick way to access options merged with those of this child's parent, if any.
  ///
  /// You might also be interested in:
  /// - [options], for getting the options unique to this child.
  CommandOptions get resolvedOptions;
}

/// An entity capable of having multiple child entities.
///
/// You might also be interested in:
/// - [ICommandRegisterable], the type that all children must implement;
/// - [ICommand], the executable command type.
abstract class ICommandGroup<T extends IContext> implements ICallHooked<T>, IChecked, IOptions {
  /// A list of all the children of this group
  Iterable<ICommandRegisterable<T>> get children;

  /// Returns an iterable that recursively iterates over all the [ICommand]s in this group.
  ///
  /// This will return all the [ICommand]s in this group, whether they be direct children or
  /// children of children. If you want all the direct [ICommand] children, consider using
  /// `children.whereType<ICommand>()` instead.
  Iterable<ICommand<T>> walkCommands();

  /// Add a command to this group.
  ///
  /// A command can be added to a group at most once; trying to do so will result in a
  /// [CommandsError] being thrown.
  void addCommand(ICommandRegisterable<T> command);

  /// Attempt to get a command from a string.
  ///
  /// In cases where multiple commands with the same name might exist, this method will only return
  /// the command most likely to be queried from a string input. For example,
  /// [CommandsPlugin.getCommand] will only return [ChatCommand]s and not [MessageCommand]s or
  /// [UserCommand]s.
  ///
  /// You might also be interested in:
  /// - [walkCommands], for iterating over all commands in this group;
  /// - [children], for iterating over the children of this group.
  ICommand<T>? getCommand(StringView view);
}

/// An entity capable of being invoked by users.
///
/// You might also be interested in:
/// - [ChatCommand], [MessageCommand] and [UserCommand], the three types of commands nyxx_commands
///   supports.
abstract class ICommand<T extends IContext> implements ICommandRegisterable<T> {
  /// The function called to execute this command.
  ///
  /// If any exception occurs while calling this function, it will be caught and added to
  /// [CommandsPlugin.onCommandError], wrapped in an [UncaughtException].
  Function get execute;

  /// Parse arguments, verify checks, call [execute] and handle call hooks.
  ///
  /// This method might throw uncaught [CommandsException]s and should be handled with care. Thrown
  /// exceptions will not be added to [CommandsPlugin.onCommandError] unless called from within a
  /// "safe" context where uncuaght exceptions are caught anyways.
  void invoke(T context);
}

/// An entity that is part of a chat command tree.
///
/// You might also be interested in:
/// - [ChatCommand] and [ChatGroup], the concrete implementations of elements in a chat command
///   tree.
abstract class IChatCommandComponent
    implements ICommandRegisterable<IChatContext>, ICommandGroup<IChatContext> {
  /// The description of this entity.
  ///
  /// This must be a non-empty string less than 100 characters in length.
  String get description;

  /// The full name of this command.
  ///
  /// A command's full name is a combination of its own name and its parent's name, allowing
  /// developers to quickly identify commands in error messages and logs.
  ///
  /// You might also be interested in:
  /// - [name], this entity's own name.
  String get fullName;

  /// The aliases for this entity.
  ///
  /// Since chat commands can be invoked from text messages and are not displayed in the UI (unless
  /// they are registered as slash commands), aliases can be used to refer to the same command with
  /// multiple different names.
  ///
  /// For example, a command that can be invoked with both `test` and `t`:
  /// ```dart
  /// ChatCommand test = ChatCommand(
  ///   'test',
  ///   'A test command',
  ///   (IChatContext context) async {
  ///     context.respond(MessageBuilder.content('Hi there!'));
  ///   },
  ///   aliases: ['t'],
  /// );
  ///
  /// commands.addCommand(test);
  /// ```
  ///
  /// ![](https://user-images.githubusercontent.com/54505189/154336688-f7ebcc15-8bb7-4ef7-bbd2-f5842acc3b19.png)
  Iterable<String> get aliases;

  /// Whether this entity has a child entity that is a slash command or has a slash command itself.
  bool get hasSlashCommand;

  /// Return the [CommandOptionBuilder]s that represent this entity for slash command registration.
  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands);
}
