import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands.dart';
import '../commands/interfaces.dart';
import '../converters/converter.dart';
import '../util/util.dart';
import 'component_context.dart';
import 'modal_context.dart';

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

  /// The instance of [IInteractions] managed by [commands].
  ///
  /// If this context originated from an interaction, this will be the instance of [IInteractions]
  /// that emitted the interaction event.
  IInteractions get interactions;
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
  @override
  final IInteractions interactions;

  ContextBase({
    required this.user,
    required this.member,
    required this.guild,
    required this.channel,
    required this.commands,
    required this.client,
    required this.interactions,
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

/// Information about how a command should respond when using [IInteractiveContext.respond].
///
/// This class mainly determines the properties of the message that is sent in response to a
/// command, such as whether it should be ephemeral or whether the user should be mentioned.
///
/// You can create an instance of this class yourself, or use one of the provided levels: [private],
/// [hint], or [public].
class ResponseLevel {
  /// A private response.
  ///
  /// Interaction responses are hidden and message responses are sent via DMs.
  static const private = ResponseLevel(
    hideInteraction: true,
    isDm: true,
    mention: null,
    preserveComponentMessages: true,
  );

  /// A response that follows how the user invoked the command.
  ///
  /// Interaction responses are hidden (as invoking a Slash Command is invisible to other users) and
  /// message responses are shown in the channel.
  static const hint = ResponseLevel(
    hideInteraction: true,
    isDm: false,
    mention: null,
    preserveComponentMessages: true,
  );

  /// A public responses.
  ///
  /// Both interaction and message responses are shown.
  static const public = ResponseLevel(
    hideInteraction: false,
    isDm: false,
    mention: null,
    preserveComponentMessages: true,
  );

  /// Whether interaction responses sent at this level should be marked as ephemeral.
  final bool hideInteraction;

  /// Whether message responses sent at this level should be sent via DM to the user.
  final bool isDm;

  /// Whether message responses sent at this level should mention the user when replying to them.
  ///
  /// If set to `null`, inherits the behaviour of the message being sent, or the global allowed
  /// mentions if the message builder does not set any.
  final bool? mention;

  /// Whether to edit the message a component belongs to or create a new message when responding to
  /// a component interaction.
  final bool preserveComponentMessages;

  /// Construct a new response level.
  ///
  /// You might also be interested in:
  /// - [private], [hint], and [public], pre-made levels for common use cases.
  const ResponseLevel({
    required this.hideInteraction,
    required this.isDm,
    required this.mention,
    required this.preserveComponentMessages,
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
  /// - [awaitButtonPress], [awaitSelection] and [awaitMultiSelection], some of the methods that can
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
  /// - [awaitButtonPress], [awaitSelection] and [awaitMultiSelection], some of the methods that can
  ///   create a context to delegate to.
  /// - [parent], the context of which this context is the delegate.
  IInteractiveContext? get delegate;

  /// The youngest context that handles all interactions.
  ///
  /// This is the same as repeatedly accessing [delegate] until it returns `null`.
  IInteractiveContext get latestContext;

  /// Send a response to the command.
  ///
  /// [level] can be set to change how the response is set. If is is not passed,
  /// [CommandOptions.defaultResponseLevel] is used instead.
  ///
  /// You might also be interested in:
  /// - [IInteractionInteractiveContext.acknowledge], for acknowledging interactions without
  /// responding.
  Future<IMessage> respond(MessageBuilder builder, {ResponseLevel? level});

  /// Wait for a user to press a button and return a context representing that button press.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with the
  /// button.
  ///
  /// You might also be interested in:
  /// - [awaitSelection] and [awaitMultiSelection], for getting a selection from a user.
  Future<ButtonComponentContext> awaitButtonPress(ComponentId componentId);

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
  Future<MultiselectComponentContext<T>> awaitSelection<T>(
    ComponentId componentId, {
    Converter<T>? converterOverride,
  });

  /// Wait for a user to select options from a multi-select menu and return a context
  /// representing that selection.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with the
  /// selection menu.
  Future<MultiselectComponentContext<List<T>>> awaitMultiSelection<T>(
    ComponentId componentId, {
    Converter<T>? converterOverride,
  });

  /// Wait for a user to press on any button on a given message and return a context representing
  /// the button press.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with a
  /// button.
  ///
  /// You might also be interested in:
  /// - [awaitButtonPress], for getting a press from a single button;
  /// - [getButtonSelection], for getting a value from a button selection;
  /// - [getSelection], for getting a selection from a multi-select menu.
  Future<ButtonComponentContext> getButtonPress(IMessage message);

  /// Get a selection from a user, presenting the options as an array of buttons.
  ///
  /// If [styles] is set, the style of a button presenting a given option will depend on the value
  /// set in the map.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with a
  /// button.
  ///
  /// [level] will change the level at which the message is sent, similarly to [respond].
  ///
  /// [toButton] and [converterOverride] can be set to change how each value is converted to a
  /// button. At most one of them may be set, and the default is to use [Converter.toButton] on the
  /// default conversion for `T`.
  ///
  /// You might also be interested in:
  /// - [getButtonPress], for getting a button press from any button on a message;
  /// - [getSelection], for getting a selection from a multi-select menu;
  /// - [getConfirmation], for getting a basic `true`/`false` selection from the user.
  Future<T> getButtonSelection<T>(
    List<T> values,
    MessageBuilder builder, {
    Map<T, ButtonStyle>? styles,
    bool authorOnly = true,
    ResponseLevel? level,
    Duration? timeout,
    FutureOr<ButtonBuilder> Function(T)? toButton,
    Converter<T>? converterOverride,
  });

  /// Present the user with two options and return whether the positive one was clicked.
  ///
  /// If [styles] is set, the style of a button presenting a given option will depend on the value
  /// set in the map. [values] can also be set to change the text displayed on each button.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with a
  /// button.
  ///
  /// [level] will change the level at which the message is sent, similarly to [respond].
  Future<bool> getConfirmation(
    MessageBuilder builder, {
    Map<bool, String> values = const {true: 'Yes', false: 'No'},
    Map<bool, ButtonStyle> styles = const {true: ButtonStyle.success, false: ButtonStyle.danger},
    bool authorOnly = true,
    ResponseLevel? level,
    Duration? timeout,
  });

  /// Present the user with a drop-down menu of choices and return the selected choice.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with a
  /// button.
  ///
  /// [level] will change the level at which the message is sent, similarly to [respond].
  ///
  /// [converterOverride] can be set to change how each value is converted to a multi-select option.
  /// The default is to use [Converter.toMultiselectOption] on the default converter for `T`.
  ///
  /// You might also be interested in:
  /// - [getMultiSelection], for getting multiple selection;
  /// - [getButtonSelection], for getting a selection from a button;
  /// - [awaitSelection], for getting a selection from a pre-existing selection menu.
  Future<T> getSelection<T>(
    List<T> choices,
    MessageBuilder builder, {
    ResponseLevel? level,
    Duration? timeout,
    bool authorOnly = true,
    FutureOr<MultiselectOptionBuilder> Function(T)? toMultiSelect,
    Converter<T>? converterOverride,
  });

  /// Present the user with a drop-down menu of choices and return the selected choices.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// If [authorOnly] is set, only the author of this interaction will be able to interact with a
  /// button.
  ///
  /// [level] will change the level at which the message is sent, similarly to [respond].
  ///
  /// [converterOverride] can be set to change how each value is converted to a multi-select option.
  /// The default is to use [Converter.toMultiselectOption] on the default converter for `T`.
  ///
  /// You might also be interested in:
  /// - [getSelection], for getting a single selection;
  /// - [getButtonSelection], for getting a selection from a button;
  /// - [awaitSelection], for getting a selection from a pre-existing selection menu.
  Future<List<T>> getMultiSelection<T>(
    List<T> choices,
    MessageBuilder builder, {
    ResponseLevel? level,
    Duration? timeout,
    bool authorOnly = true,
    FutureOr<MultiselectOptionBuilder> Function(T)? toMultiSelect,
    Converter<T>? converterOverride,
  });
}

/// A context that can be interacted with and originated from an interaction.
///
/// You might also be interested in:
/// - [IInteractionContextData], which contains data about interactions.
abstract class IInteractionInteractiveContext implements IInteractiveContext {
  /// Acknowledge the underlying interaction without yet sending a response.
  ///
  /// [level] can be used to change whether the response should be hidden or not.
  ///
  /// You might also be interested in:
  /// - [respond], for sending a full response.
  Future<void> acknowledge({ResponseLevel? level});

  /// Wait for a user to submit a modal and return a context representing that submission.
  ///
  /// [customId] is the id of the modal to wait for.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// You might also be interested in:
  /// - [awaitSelection] and [awaitMultiSelection], for getting a selection from a user.
  Future<ModalContext> awaitModal(String customId, {Duration? timeout});

  /// Present the user with a modal, wait for them to submit it, and return a context representing
  /// that submission.
  ///
  /// [title] is the title of the modal that should be shown to the user.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout] has passed.
  ///
  /// [components] are the text inputs that will be presented to the user. The
  /// [TextInputBuilder.customId] can be later used with [ModalContext.operator[]] to get the value
  /// submitted by the user.
  Future<ModalContext> getModal({
    required String title,
    required List<TextInputBuilder> components,
    Duration? timeout,
  });
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
