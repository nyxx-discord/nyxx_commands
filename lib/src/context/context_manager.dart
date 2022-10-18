import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands.dart';
import '../commands/chat_command.dart';
import '../commands/message_command.dart';
import '../commands/user_command.dart';
import '../errors.dart';
import '../util/view.dart';
import 'autocomplete_context.dart';
import 'chat_context.dart';
import 'component_context.dart';
import 'message_context.dart';
import 'user_context.dart';

/// Exposes methods for creating contexts from the raw event dispatched from Discord.
///
/// You do not need to create this class yourself; it is exposed through
/// [CommandsPlugin.contextManager].
class ContextManager {
  /// The [CommandsPlugin] this [ContextManager] is attached to.
  ///
  /// All contexts created by this [ContextManager] will include [commands] as [IContext.commands].
  ///
  /// You might also be interested in:
  /// - [IContext.commands], the property which exposes the [CommandsPlugin] to commands.
  final CommandsPlugin commands;

  /// Create a new [ContextManager] attached to a [CommandsPlugin].
  ContextManager(this.commands);

  /// Create a [MessageChatContext] from an [IMessage].
  ///
  /// [message] is the message that triggered the command, [contentView] is a [StringView] of the
  /// message's content with the prefix already skipped and [prefix] is the content of the match
  /// that was skipped.
  ///
  /// Throws a [CommandNotFoundException] if [message] did not match any command on [commands].
  ///
  /// You might also be interested in:
  /// - [createInteractionChatContext], for creating [IChatContext]s from interaction events.
  Future<MessageChatContext> createMessageChatContext(
    IMessage message,
    StringView contentView,
    String prefix,
  ) async {
    ChatCommand command =
        commands.getCommand(contentView) ?? (throw CommandNotFoundException(contentView));

    ITextChannel channel = await message.channel.getOrDownload();

    IGuild? guild;
    IMember? member;
    IUser user;
    if (message.guild != null) {
      guild = await message.guild!.getOrDownload();

      member = message.member;
      user = await member!.user.getOrDownload();
    } else {
      user = message.author as IUser;
    }

    return MessageChatContext(
      commands: commands,
      guild: guild,
      channel: channel,
      member: member,
      user: user,
      command: command,
      client: commands.client!,
      prefix: prefix,
      message: message,
      rawArguments: contentView.remaining,
    );
  }

  /// Create an [InteractionChatContext] from an [ISlashCommandInteractionEvent].
  ///
  /// [interactionEvent] is the interaction event that triggered the command and [command] is the
  /// command executed by the event.
  ///
  /// You might also be interested in:
  /// - [createMessageChatContext], for creating [IChatContext]s from message events.
  Future<InteractionChatContext> createInteractionChatContext(
    ISlashCommandInteractionEvent interactionEvent,
    ChatCommand command,
  ) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    Map<String, dynamic> rawArguments = <String, dynamic>{};

    for (final option in interactionEvent.args) {
      rawArguments[option.name] = option.value;
    }

    return InteractionChatContext(
      commands: commands,
      guild: await interaction.guild?.getOrDownload(),
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      command: command,
      client: commands.client!,
      interaction: interaction,
      rawArguments: rawArguments,
      interactionEvent: interactionEvent,
    );
  }

  /// Create a [UserContext] from an [ISlashCommandInteractionEvent].
  ///
  /// [interactionEvent] is the interaction event that triggered the command and [command] is the
  /// command executed by the event.
  Future<UserContext> createUserContext(
    ISlashCommandInteractionEvent interactionEvent,
    UserCommand command,
  ) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    IUser targetUser = commands.client!.users[interaction.targetId] ??
        await commands.client!.httpEndpoints.fetchUser(interaction.targetId!);

    IGuild? guild = await interaction.guild?.getOrDownload();

    return UserContext(
      commands: commands,
      client: commands.client!,
      interactionEvent: interactionEvent,
      interaction: interaction,
      command: command,
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      guild: guild,
      targetUser: targetUser,
      targetMember: guild?.members[targetUser.id] ?? await guild?.fetchMember(targetUser.id),
    );
  }

  /// Create a [MessageContext] from an [ISlashCommandInteractionEvent].
  ///
  /// [interactionEvent] is the interaction event that triggered the command and [command] is the
  /// command executed by the event.
  Future<MessageContext> createMessageContext(
    ISlashCommandInteractionEvent interactionEvent,
    MessageCommand command,
  ) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    IGuild? guild = await interaction.guild?.getOrDownload();

    return MessageContext(
      commands: commands,
      client: commands.client!,
      interactionEvent: interactionEvent,
      interaction: interaction,
      command: command,
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      guild: guild,
      targetMessage: interaction.channel.getFromCache()!.messageCache[interaction.targetId] ??
          await interaction.channel.getFromCache()!.fetchMessage(interaction.targetId!),
    );
  }

  /// Create an [AutocompleteContext] from an [IAutocompleteInteractionEvent].
  ///
  /// [interactionEvent] is the interaction event that triggered the autocomplete action and
  /// [command] is the command to which the autocompleted parameter belongs.
  Future<AutocompleteContext> createAutocompleteContext(
    IAutocompleteInteractionEvent interactionEvent,
    ChatCommand command,
  ) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    return AutocompleteContext(
      commands: commands,
      guild: await interaction.guild?.getOrDownload(),
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      command: command,
      client: commands.client!,
      interaction: interaction,
      interactionEvent: interactionEvent,
      option: interactionEvent.focusedOption,
      currentValue: interactionEvent.focusedOption.value.toString(),
    );
  }

  /// Create a [ButtonComponentContext] from an [IButtonInteractionEvent].
  ///
  /// [interactionEvent] is the interaction event that triggered this context's creation.
  Future<ButtonComponentContext> createButtonComponentContext(
    IButtonInteractionEvent interactionEvent,
  ) async {
    IButtonInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    return ButtonComponentContext(
      user: user,
      member: member,
      guild: await interaction.guild?.getOrDownload(),
      channel: await interaction.channel.getOrDownload(),
      commands: commands,
      client: commands.client!,
      interaction: interaction,
      interactionEvent: interactionEvent,
    );
  }

  /// Create a [MultiselectComponentContext] from an [IMultiselectInteractionEvent].
  ///
  /// [interactionEvent] is the interaction event that triggered this context's creation and
  /// [selected] is the value(s) that were selected by the user.
  Future<MultiselectComponentContext<T>> createMultiselectComponentContext<T>(
    IMultiselectInteractionEvent interactionEvent,
    T selected,
  ) async {
    IMultiselectInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    return MultiselectComponentContext(
      user: user,
      member: member,
      guild: await interaction.guild?.getOrDownload(),
      channel: await interaction.channel.getOrDownload(),
      commands: commands,
      client: commands.client!,
      interaction: interaction,
      interactionEvent: interactionEvent,
      selected: selected,
    );
  }
}
