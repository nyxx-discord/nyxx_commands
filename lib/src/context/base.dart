import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/context/component_context.dart';
import 'package:nyxx_commands/src/converters/converter.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands.dart';
import '../commands/interfaces.dart';

/// The base class for all contexts in nyxx_commands.
///
/// Contains data that all contexts provide.
///
/// You might also be interested in:
/// - [ICommandContextData], which contains data about contexts which execute a command.
abstract class IContextData {
  /// The user that triggered this context's creation.
  IUser get user;

  /// The member that triggered this context's created, or `null` if created outside of a guild.
  IMember? get member;

  /// The guild in which the context was created, or `null` if created outside of a guild.
  IGuild? get guild;

  /// The channel in which the context was created.
  ITextChannel get channel;

  /// The instance of [CommandsPlugin] which created this context.
  CommandsPlugin get commands;

  /// The client that emitted the event triggering this context's creation.
  INyxx get client;
}

class ContextBase implements IContextData {
  @override
  final IUser user;
  @override
  final IMember? member;
  @override
  final IGuild? guild;
  @override
  final ITextChannel channel;
  @override
  final CommandsPlugin commands;
  @override
  final INyxx client;

  ContextBase({
    required this.user,
    required this.member,
    required this.guild,
    required this.channel,
    required this.commands,
    required this.client,
  });
}

/// Data about a context in which a command was executed.
///
/// You might also be interested in:
/// - [ICommandContext], which exposes the functionality for interacting with this context.
/// - [IContextData], the base class for all contexts.
abstract class ICommandContextData implements IContextData {
  /// The command that was executed or is being processed.
  ICommand<ICommandContext> get command;
}

class ResponseLevel {
  // Private
  static const private = ResponseLevel(hideInteraction: true, isDm: true, mention: null);

  // Hint
  static const quietHint = ResponseLevel(hideInteraction: true, isDm: false, mention: false);
  static const hint = ResponseLevel(hideInteraction: true, isDm: false, mention: null);
  static const loudHint = ResponseLevel(hideInteraction: true, isDm: false, mention: null);

  // Public
  static const quietPublic = ResponseLevel(hideInteraction: false, isDm: false, mention: false);
  static const public = ResponseLevel(hideInteraction: false, isDm: false, mention: null);
  static const loudPublic = ResponseLevel(hideInteraction: false, isDm: false, mention: true);

  final bool hideInteraction;
  final bool isDm;
  final bool? mention;

  const ResponseLevel({
    required this.hideInteraction,
    required this.isDm,
    required this.mention,
  });
}

/// A context that can be interacted with.
///
/// You might also be interested in:
/// - [IInteractionInteractiveContext], for contexts that originate from an interaction.
abstract class IInteractiveContext {
  /// The parent of this context.
  ///
  /// If this context was created by an operation on another context, this will be that context.
  /// Otherwise, this is `null`.
  ///
  /// You might also be interested in:
  /// - [getButtonPress], [getSelection] and [getMultiSelection], some of the methods that can
  ///   create a child context;
  /// - [delegate], the context that has this context as its parent.
  IInteractiveContext? get parent;

  /// The delegate of this context.
  ///
  /// If this is set, most operations on this context will be forwarded to this context instead.
  /// This prevents contexts from going stale when waiting for a user to interact and makes the
  /// command flow more accurate in the Discord UI.
  ///
  /// You might also be interested in:
  /// - [getButtonPress], [getSelection] and [getMultiSelection], some of the methods that can
  ///   create a context to delegate to.
  /// - [parent], the context of which this context is the delegate.
  IInteractiveContext? get delegate;

  /// Send a response to the command.
  ///
  /// If [private] is set to `true`, then the response will only be made visible to the user that
  /// invoked the command. In interactions, this is done by sending an ephemeral response, in text
  /// commands this is handled by sending a Private Message to the user.
  ///
  /// You might also be interested in:
  /// - [IInteractionContext.acknowledge], for acknowledging interactions without responding.
  Future<IMessage> respond(MessageBuilder builder, {ResponseLevel? level});

  /// Wait for a user to press a button and return a context representing that button press.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with the
  /// button.
  ///
  /// You might also be interested in:
  /// - [getSelection] and [getMultiSelection], for getting a selection from a user.
  Future<ButtonComponentContext> getButtonPress(
    String componentId, {
    Duration? timeout = const Duration(minutes: 10),
    bool authorOnly = true,
  });

  /// Wait for a user to select a single option from a multi-select menu and return a context
  /// representing that selection.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with the
  /// selection menu.
  ///
  /// Will throw a [StateError] if more than one option is selected (for example, from a
  /// multi-select menu allowing more than one choice).
  Future<MultiselectComponentContext<T>> getSelection<T>(
    String componentId, {
    Duration? timeout = const Duration(minutes: 10),
    bool authorOnly = true,
    Converter<T>? converterOverride,
  });

  /// Wait for a user to select options from a multi-select menu and return a context
  /// representing that selection.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with the
  /// selection menu.
  Future<MultiselectComponentContext<List<T>>> getMultiSelection<T>(
    String componentId, {
    Duration? timeout = const Duration(minutes: 10),
    bool authorOnly = true,
    Converter<T>? converterOverride,
  });
}

/// A context that can be interacted with and originated from an interaction.
///
/// You might also be interested in:
/// - [IInteractionContextData], which contains data about interactions.
abstract class IInteractionInteractiveContext implements IInteractiveContext {
  @override
  Future<IMessage> respond(MessageBuilder builder, {ResponseLevel? level});

  /// Acknowledge the underlying interaction without yet sending a response.
  ///
  /// While the `hidden` and `private` arguments are guaranteed to hide/show the resulting response,
  /// slow commands might sometimes show strange behavior in their responses. Acknowledging the
  /// interaction early with the correct value for [hidden] can prevent this behavior.
  ///
  /// You might also be interested in:
  /// - [respond], for sending a full response.
  Future<void> acknowledge({ResponseLevel? level});
}

/// A context in which a command was executed.
///
/// Contains data about how and where the command was executed, and provides a simple interfaces for
/// responding to commands.
///
/// You might also be interested in:
/// - [ICommandContextData], which exposes the data found in this context;
/// - [IInteractionCommandContext], a context in which a command was executed from an interaction;
/// - [MessageChatContext], a context in which a command was executed from a text message.
abstract class ICommandContext implements ICommandContextData, IInteractiveContext {}

/// Data about a context which was created by an interaction.
///
/// You might also be interested in:
/// - [IInteractionCommandContextData], data about a context in which a command was executed from an
///   interaction;
/// - [IContextData], the base class for all contexts.
abstract class IInteractionContextData implements IContextData {
  /// The interaction that triggered this context's creation.
  IInteraction get interaction;

  /// The interaction event that triggered this context's creation.
  IInteractionEvent get interactionEvent;
}

/// Data about a context in which a command was executed from an interaction.
///
/// You might also be interested in:
/// - [IInteractionCommandContext], which exposes functionality for interacting with this context;
/// - [IInteractionContextData], the base class for all contexts created from interactions.
abstract class IInteractionCommandContextData implements IInteractionContextData {
  @override
  ISlashCommandInteraction get interaction;

  @override
  ISlashCommandInteractionEvent get interactionEvent;
}

/// A context in which a command was executed from an interaction.
///
/// Contains data about how and where the command was executed, and provides a simple interfaces for
/// responding to commands.
///
/// You might also be interested in:
/// - [IInteractionCommandContextData], which exposes the data found in this context,
/// - [ICommandContext], the base class for all contexts representing a command execution.
abstract class IInteractionCommandContext
    implements IInteractionCommandContextData, ICommandContext, IInteractionInteractiveContext {}
