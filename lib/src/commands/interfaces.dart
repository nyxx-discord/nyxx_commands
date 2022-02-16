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

import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/commands/options.dart';
import 'package:nyxx_commands/src/context/chat_context.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:nyxx_commands/src/util/view.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

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

abstract class IChecked {
  Iterable<AbstractCheck> get checks;

  void check(AbstractCheck check);
}

abstract class IOptions {
  CommandOptions get options;
}

abstract class ICommandRegisterable<T extends IContext>
    implements ICallHooked<T>, IChecked, IOptions {
  String get name;

  ICommandGroup<IContext>? get parent;
  set parent(ICommandGroup<IContext>? parent);

  CommandOptions get resolvedOptions;
}

abstract class ICommandGroup<T extends IContext> implements ICallHooked<T>, IChecked, IOptions {
  Iterable<ICommandRegisterable<T>> get children;

  Iterable<ICommand<T>> walkCommands();

  void addCommand(ICommandRegisterable<T> command);

  ICommand<T>? getCommand(StringView view);
}

abstract class ICommand<T extends IContext> implements ICommandRegisterable<T> {
  Function get execute;

  void invoke(T context);
}

abstract class IChatCommandComponent
    implements ICommandRegisterable<IChatContext>, ICommandGroup<IChatContext> {
  String get description;

  String get fullName;

  Iterable<String> get aliases;

  bool get hasSlashCommand;

  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands);
}
