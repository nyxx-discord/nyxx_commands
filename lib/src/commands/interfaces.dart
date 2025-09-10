import 'package:nyxx/nyxx.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../commands/chat_command.dart';
import '../context/base.dart';
import '../context/chat_context.dart';
import '../errors.dart';
import '../util/view.dart';
import 'options.dart';

/// Represents an entity which can handle command callback hooks.
abstract class CallHooked<T extends CommandContext> {
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
abstract class Checked {
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
/// Command options can influence a command's behavior and how it can be invoked. Options are
/// inherited.
abstract class Options {
  /// The options to use for this entity.
  CommandOptions get options;
}

/// Represents an entity that can be added as a child to a command group.
///
/// You might also be interested in:
/// - [CommandGroup], the interface for groups that [CommandRegisterable]s can be added to.
abstract class CommandRegisterable<T extends CommandContext> implements CallHooked<T>, Checked, Options {
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
  CommandGroup<CommandContext>? get parent;

  /// Set the parent of this child. Should not be used unless you are implementing your own command
  /// group.
  set parent(CommandGroup<CommandContext>? parent);

  /// Get the resolved options for this child.
  ///
  /// Since [CommandRegisterable] implements [Options], any class implementing this interface can
  /// provide options. However, since options are designed to be inherited, this getter provides a
  /// quick way to access options merged with those of this child's parent, if any.
  ///
  /// You might also be interested in:
  /// - [options], for getting the options unique to this child.
  CommandOptions get resolvedOptions;

  /// The localized names of this child.
  /// Since you cannot add descriptions to [UserCommand] and [MessageCommand], can't set localized descriptions too.
  ///
  /// ```dart
  /// ChatCommand test = ChatCommand(
  ///  'hi',
  ///  'A test command',
  ///  (
  ///   IChatContext context,
  ///   @Name('message', {Locale.german: 'hallo'}) String foo,
  ///  ) async => context.respond(MessageBuilder.content(foo))
  /// );
  /// ```
  /// Will be displayed as 'hallo' in German, like so:
  ///
  /// ![](https://user-images.githubusercontent.com/74512338/173841767-6e2c5215-ebc3-4a89-a2ac-8115949e2f0b.png)
  Map<Locale, String>? get localizedNames;
}

/// An entity capable of having multiple child entities.
///
/// You might also be interested in:
/// - [CommandRegisterable], the type that all children must implement;
/// - [Command], the executable command type.
abstract class CommandGroup<T extends CommandContext> implements CallHooked<T>, Checked, Options {
  /// A list of all the children of this group
  Iterable<CommandRegisterable<T>> get children;

  /// Returns an iterable that recursively iterates over all the [Command]s in this group.
  ///
  /// This will return all the [Command]s in this group, whether they be direct children or
  /// children of children. If you want all the direct [Command] children, consider using
  /// `children.whereType<ICommand>()` instead.
  Iterable<Command<T>> walkCommands();

  /// Add a command to this group.
  ///
  /// A command can be added to a group at most once; trying to do so will result in a
  /// [CommandsError] being thrown.
  void addCommand(covariant CommandRegisterable<T> command);

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
  Command<T>? getCommand(StringView view);
}

/// An entity capable of being invoked by users.
///
/// You might also be interested in:
/// - [ChatCommand], [MessageCommand] and [UserCommand], the three types of commands nyxx_commands
///   supports.
abstract class Command<T extends CommandContext> implements CommandRegisterable<T> {
  /// The function called to execute this command.
  ///
  /// If any exception occurs while calling this function, it will be caught and added to
  /// [CommandsPlugin.onCommandError], wrapped in an [UncaughtException].
  Function get execute;

  /// Parse arguments, verify checks, call [execute] and handle call hooks.
  ///
  /// This method might throw uncaught [CommandsException]s and should be handled with care. Thrown
  /// exceptions will not be added to [CommandsPlugin.onCommandError] unless called from within a
  /// "safe" context where uncaught exceptions are caught anyways.
  Future<void> invoke(T context);
}

/// An entity that is part of a chat command tree.
///
/// You might also be interested in:
/// - [ChatCommand] and [ChatGroup], the concrete implementations of elements in a chat command
///   tree.
abstract class ChatCommandComponent implements CommandRegisterable<ChatContext>, CommandGroup<ChatContext> {
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

  /// The localized descriptions of this entity.
  ///
  /// The localized descriptions for the command.
  ///
  /// ```dart
  /// ChatCommand test = ChatCommand(
  ///  'hi',
  ///  'A test command',
  ///   (
  ///     IChatContext context,
  ///     @Description('This is a description', {Locale.german: 'Dies ist eine Beschreibung'})
  ///         String foo,
  ///   ) async {
  ///     context.respond(MessageBuilder.content(foo));
  ///   },
  /// );
  /// ```
  /// Will be displayed as `This is a description` in English, but `Dies ist eine Beschreibung` in German, like so:
  ///
  /// ![](https://user-images.githubusercontent.com/74512338/174033266-88017e8a-bc13-4031-bf9d-31f9343967a4.png)
  Map<Locale, String>? get localizedDescriptions;

  /// Return the [CommandOptionBuilder]s that represent this entity for slash command registration.
  List<CommandOptionBuilder> getOptions(CommandsPlugin commands);

  @override
  ChatCommand? getCommand(StringView view);

  @override
  Iterable<ChatCommand> walkCommands();

  @override
  Iterable<ChatCommandComponent> get children;
}
