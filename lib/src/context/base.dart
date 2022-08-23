import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands.dart';
import '../commands/interfaces.dart';

/// The base class for all contexts in nyxx_commands.
///
/// Contains data that all contexts provide.
abstract class IContextBaseData {
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

class ContextBase implements IContextBaseData {
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

/// The base class for all contexts which execute a command.
abstract class ICommandContextData implements IContextBaseData {
  /// The command that was executed or is being processed.
  ICommand<ICommandContext> get command;
}

/// A context in which a command was executed.
///
/// Contains data about how and where the command was executed, and provides a simple interfaces for
/// responding to commands.
abstract class ICommandContext implements ICommandContextData {
  /// Send a response to the command.
  ///
  /// If [private] is set to `true`, then the response will only be made visible to the user that
  /// invoked the command. In interactions, this is done by sending an ephemeral response, in text
  /// commands this is handled by sending a Private Message to the user.
  ///
  /// You might also be interested in:
  /// - [IInteractionContext.acknowledge], for acknowledging interactions without responding.
  Future<IMessage> respond(MessageBuilder builder, {bool private = false});

  /// Wait for a user to make a selection from a multiselect menu, then return the result of that
  /// interaction.
  ///
  /// If [authorOnly] is `true`, only events triggered by the author of this context will be
  /// returned, but other interactions will still be acknowledged.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout].
  Future<IMultiselectInteractionEvent> getSelection(MultiselectBuilder selectionMenu,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  /// Wait for a user to press on a button, then return the result of that interaction.
  ///
  /// This method specifically listens for interactions on items of [buttons], ignoring other button
  /// presses.
  ///
  /// If [authorOnly] is `true`, only events triggered by the author of this context will be
  /// returned, but other interactions will still be acknowledged.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout].
  ///
  /// You might also be interested in:
  /// - [getConfirmation], a shortcut for getting user confirmation from buttons.
  Future<IButtonInteractionEvent> getButtonPress(Iterable<ButtonBuilder> buttons,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  /// Send a message prompting a user for confirmation, then return whether the user accepted the
  /// choice.
  ///
  /// If [authorOnly] is `true`, only events triggered by the author of this context will be
  /// returned, but other interactions will still be acknowledged.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout].
  ///
  /// [confirmMessage] and [denyMessage] can be set to change the text displayed on the "confirm"
  /// and "deny" buttons.
  Future<bool> getConfirmation(MessageBuilder message,
      {bool authorOnly = true,
      Duration? timeout = const Duration(minutes: 12),
      String confirmMessage = 'Yes',
      String denyMessage = 'No'});
}

/// The base class for all interaction-triggered contexts in nyxx_commands.
///
/// Contains data allowing access to the underlying interaction that triggered the context's
/// creation.
abstract class IInteractionContextBaseData implements IContextBaseData {
  /// The interaction that triggered this context's creation.
  IInteraction get interaction;

  /// The interaction event that triggered this context's creation.
  IInteractionEvent get interactionEvent;
}

/// The base class for all context which execute a command and originate from an interaction.
abstract class IInteractionCommandContext implements IInteractionContextBaseData, ICommandContext {
  @override
  ISlashCommandInteraction get interaction;

  @override
  ISlashCommandInteractionEvent get interactionEvent;

  @override
  Future<IMessage> respond(MessageBuilder builder, {bool private = false, bool? hidden});

  /// Acknowledge the underlying interaction without yet sending a response.
  ///
  /// While the `hidden` and `private` arguments are guaranteed to hide/show the resulting response,
  /// slow commands might sometimes show strange behavior in their responses. Acknowledging the
  /// interaction early with the correct value for [hidden] can prevent this behavior.
  ///
  /// You might also be interested in:
  /// - [respond], for sending a full response.
  Future<void> acknowledge({bool? hidden});
}

mixin InteractionRespondMixin implements IInteractionCommandContext, IInteractionContextBaseData {
  bool _hasCorrectlyAcked = false;
  late bool _originalAckHidden = commands.options.hideOriginalResponse;

  @override
  Future<IMessage> respond(MessageBuilder builder, {bool private = false, bool? hidden}) async {
    hidden ??= private;

    if (_hasCorrectlyAcked) {
      return interactionEvent.sendFollowup(builder, hidden: hidden);
    } else {
      _hasCorrectlyAcked = true;
      try {
        await interactionEvent.acknowledge(hidden: hidden);
      } on AlreadyRespondedError {
        // interaction was already ACKed by timeout or [acknowledge], hidden state of ACK might not
        // be what we expect
        if (_originalAckHidden != hidden) {
          await interactionEvent
              .sendFollowup(MessageBuilder.content(MessageBuilder.clearCharacter));
          if (!_originalAckHidden) {
            // If original response was hidden, we can't delete it
            await interactionEvent.deleteOriginalResponse();
          }
        }
      }
      return interactionEvent.sendFollowup(builder, hidden: hidden);
    }
  }

  @override
  Future<void> acknowledge({bool? hidden}) async {
    await interactionEvent.acknowledge(hidden: hidden ?? commands.options.hideOriginalResponse);
    _originalAckHidden = hidden ?? commands.options.hideOriginalResponse;
  }
}
