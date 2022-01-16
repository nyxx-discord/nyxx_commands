import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/context/chat_context.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:nyxx_commands/src/util/view.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// Represents an entity with the ability to register pre- and post- call hooks.
abstract class ICallHooked<T extends IContext> {
  /// A [Stream] of [IContext]s that emits after the checks have succeeded, but before
  /// [ICommand.execute] is called in this command or its children.
  Stream<T> get onPreCall;

  /// A [Stream] of [IContext]s that emits after [ICommand.execute] has successfully been called (no
  /// exceptions were thrown) in this command or its children.
  Stream<T> get onPostCall;
}

/// Represents an entity that has checks that govern a command's execution.
abstract class IChecked {
  /// An [Iterable] of checks that must succeed for this command to be executed.
  Iterable<AbstractCheck> get checks;

  /// Add a check to this command.
  void check(AbstractCheck check);
}

/// Represents an entity that can be registered in an [ICommandGroup].
abstract class ICommandRegisterable<T extends IContext> implements ICallHooked<T>, IChecked {
  /// The name of this command.
  ///
  /// This must match [commandNameRegex] and be composed of the lowercase variant of letters where
  /// available if this command is a chat command.s
  String get name;

  /// The parent of this group, if any.
  ICommandGroup<IContext>? get parent;
  set parent(ICommandGroup<IContext>? parent);
}

/// Represents a collection of [ICommandRegisterable]s.
///
/// This could be a subcommand group, but this class carries no connection to the Discord API. For
/// that, use [ChatGroup].
abstract class ICommandGroup<T extends IContext> implements ICallHooked<T>, IChecked {
  /// An iterable of all this groups children.
  Iterable<ICommandRegisterable<T>> get children;

  /// Iterate over all the commands in this group and any subgroups.
  Iterable<ICommand<T>> walkCommands();

  /// Add a child to this group.
  ///
  /// If any of its name or aliases confict with already registered commands, a
  /// [CommandRegistrationError] is thrown.
  ///
  /// If [child] already has a parent, an [CommandRegistrationError] is thrown.
  void addCommand(ICommandRegisterable<T> command);

  /// Get a [Command] based off a [StringView].
  ///
  /// This is usually used to obtain the command being executed in a message, after the prefix has
  /// been skipped in the view.
  ICommand<T>? getCommand(StringView view);
}

/// Represents a command that can be invoked.
abstract class ICommand<T extends IContext> implements ICommandRegisterable<T> {
  /// The callback function for this command.
  ///
  /// The first argument to this function must be a [IContext]. Slash and text commands might have
  /// additional parameter and optional parameter, but user and message commands may not have
  /// additional parameter.
  Function get execute;

  /// The function called to invoke the command.
  void invoke(T context);
}

/// Represents an entity that is part of a Chat Command.
///
/// This could be a subcommand group or a slash command.
abstract class IChatCommandComponent
    implements ICommandRegisterable<IChatContext>, ICommandGroup<IChatContext> {
  /// The description of this command. This must be less than 100 characters in length and may not
  /// be empty.
  String get description;

  /// The full name of this group.
  ///
  /// The full name of a group is its name appended to its parents [fullName].
  String get fullName;

  /// A list of aliases that can also be used to refer to this group.
  Iterable<String> get aliases;

  /// Whether this group contains any slash commands.
  ///
  /// These might not be direct children, and can be nested multiple layers for this method to
  /// return true.
  bool get hasSlashCommand;

  /// Build the options for registering this group to the Discord API for slash commands.
  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands);
}
