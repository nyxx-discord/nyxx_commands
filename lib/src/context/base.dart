import 'dart:async';

import 'package:nyxx/nyxx.dart';

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
/// - [CommandContextData], which contains data about contexts which execute a command.
abstract interface class ContextData {
  /// The user that triggered this context's creation.
  User get user;

  /// The member that triggered this context's created, or `null` if created outside of a guild.
  Member? get member;

  /// The guild in which the context was created, or `null` if created outside of a guild.
  Guild? get guild;

  /// The channel in which the context was created.
  TextChannel get channel;

  /// The instance of [CommandsPlugin] which created this context.
  CommandsPlugin get commands;

  /// The client that emitted the event triggering this context's creation.
  NyxxGateway get client;
}

/// Data about a context in which a command was executed.
///
/// You might also be interested in:
/// - [CommandContext], which exposes the functionality for interacting with this context.
/// - [ContextData], the base class for all contexts.
abstract interface class CommandContextData implements ContextData {
  /// The command that was executed or is being processed.
  Command<CommandContext> get command;
}

/// A context that can be interacted with.
///
/// You might also be interested in:
/// - [InteractionInteractiveContext], for contexts that originate from an interaction.
abstract interface class InteractiveContext {
  /// The parent of this context.
  ///
  /// If this context was created by an operation on another context, this will be that context.
  /// Otherwise, this is `null`.
  ///
  /// You might also be interested in:
  /// - [awaitButtonPress], [awaitSelection] and [awaitMultiSelection], some of the methods that can
  ///   create a child context;
  /// - [delegate], the context that has this context as its parent.
  InteractiveContext? get parent;

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
  InteractiveContext? get delegate;

  /// The youngest context that handles all interactions.
  ///
  /// This is the same as repeatedly accessing [delegate] until it returns `null`.
  InteractiveContext get latestContext;

  /// Send a response to the command.
  ///
  /// [level] can be set to change how the response is set. If is is not passed,
  /// [CommandOptions.defaultResponseLevel] is used instead.
  ///
  /// You might also be interested in:
  /// - [InteractionInteractiveContext.acknowledge], for acknowledging interactions without
  /// responding.
  Future<Message> respond(MessageBuilder builder, {ResponseLevel? level});

  /// Wait for a user to press a button and return a context representing that button press.
  ///
  /// You might also be interested in:
  /// - [awaitSelection] and [awaitMultiSelection], for getting a selection from a user.
  Future<ButtonComponentContext> awaitButtonPress(ComponentId componentId);

  /// Wait for a user to select a single option from a multi-select menu and return a context
  /// representing that selection.
  ///
  /// Will throw a [StateError] if more than one option is selected (for example, from a
  /// multi-select menu allowing more than one choice).
  Future<SelectMenuContext<T>> awaitSelection<T>(
    ComponentId componentId, {
    Converter<T>? converterOverride,
  });

  /// Wait for a user to select options from a multi-select menu and return a context
  /// representing that selection.
  Future<SelectMenuContext<List<T>>> awaitMultiSelection<T>(
    ComponentId componentId, {
    Converter<T>? converterOverride,
  });

  /// Wait for a user to press on any button on a given message and return a context representing
  /// the button press.
  ///
  /// You might also be interested in:
  /// - [awaitButtonPress], for getting a press from a single button;
  /// - [getButtonSelection], for getting a value from a button selection;
  /// - [getSelection], for getting a selection from a multi-select menu.
  Future<ButtonComponentContext> getButtonPress(Message message);

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
  /// The default is to use [Converter.toSelectMenuOption] on the default converter for `T`.
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
    FutureOr<SelectMenuOptionBuilder> Function(T)? toSelectMenuOption,
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
  /// The default is to use [Converter.toSelectMenuOption] on the default converter for `T`.
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
    FutureOr<SelectMenuOptionBuilder> Function(T)? toSelectMenuOption,
    Converter<T>? converterOverride,
  });
}

/// A context that can be interacted with and originated from an interaction.
///
/// You might also be interested in:
/// - [InteractionContextData], which contains data about interactions.
abstract interface class InteractionInteractiveContext implements InteractiveContext {
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
/// - [CommandContextData], which exposes the data found in this context;
/// - [InteractionCommandContext], a context in which a command was executed from an interaction;
/// - [MessageChatContext], a context in which a command was executed from a text message.
abstract interface class CommandContext implements CommandContextData, InteractiveContext {}

/// Data about a context which was created by an interaction.
///
/// You might also be interested in:
/// - [InteractionCommandContextData], data about a context in which a command was executed from an
///   interaction;
/// - [ContextData], the base class for all contexts.
abstract interface class InteractionContextData implements ContextData {
  /// The interaction that triggered this context's creation.
  Interaction<dynamic> get interaction;
}

/// Data about a context in which a command was executed from an interaction.
///
/// You might also be interested in:
/// - [InteractionCommandContext], which exposes functionality for interacting with this context;
/// - [InteractionContextData], the base class for all contexts created from interactions.
abstract interface class InteractionCommandContextData implements InteractionContextData {
  @override
  ApplicationCommandInteraction get interaction;
}

/// A context in which a command was executed from an interaction.
///
/// Contains data about how and where the command was executed, and provides a simple interfaces for
/// responding to commands.
///
/// You might also be interested in:
/// - [InteractionCommandContextData], which exposes the data found in this context,
/// - [CommandContext], the base class for all contexts representing a command execution.
abstract interface class InteractionCommandContext
    implements InteractionCommandContextData, CommandContext, InteractionInteractiveContext {}

/// Information about how a command should respond when using [InteractiveContext.respond].
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

  /// Create a new [ResponseLevel] identical to this one with one or more fields changed.
  ///
  /// [mention] cannot be updated to be `null` due to a technical limitation with Dart.
  // We'd need a senitel value to tell if an argument was actually passed to `mention` (to
  // differentiate between `null` and nothing passed at all). While this is possible, it's overly
  // verbose and complicated, so we just don't support it.
  ResponseLevel copyWith({
    bool? hideInteraction,
    bool? isDm,
    bool? mention,
    bool? preserveComponentMessages,
  }) {
    return ResponseLevel(
      hideInteraction: hideInteraction ?? this.hideInteraction,
      isDm: isDm ?? this.isDm,
      mention: mention ?? this.mention,
      preserveComponentMessages: preserveComponentMessages ?? this.preserveComponentMessages,
    );
  }
}

class ContextBase implements ContextData {
  @override
  final User user;
  @override
  final Member? member;
  @override
  final Guild? guild;
  @override
  final TextChannel channel;
  @override
  final CommandsPlugin commands;
  @override
  final NyxxGateway client;

  ContextBase({
    required this.user,
    required this.member,
    required this.guild,
    required this.channel,
    required this.commands,
    required this.client,
  });
}
