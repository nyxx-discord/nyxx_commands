import 'package:nyxx/nyxx.dart';

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
import 'modal_context.dart';
import 'user_context.dart';

/// Exposes methods for creating contexts from the raw event dispatched from Discord.
///
/// You do not need to create this class yourself; it is exposed through
/// [CommandsPlugin.contextManager].
class ContextManager {
  /// The [CommandsPlugin] this [ContextManager] is attached to.
  ///
  /// All contexts created by this [ContextManager] will include [commands] as
  /// [ContextData.commands].
  ///
  /// You might also be interested in:
  /// - [ContextData.commands], the property which exposes the [CommandsPlugin] to commands.
  final CommandsPlugin commands;

  /// Create a new [ContextManager] attached to a [CommandsPlugin].
  ContextManager(this.commands);

  /// Create a [MessageChatContext] from a [Message].
  ///
  /// [message] is the message that triggered the command, [contentView] is a [StringView] of the
  /// message's content with the prefix already skipped and [prefix] is the content of the match
  /// that was skipped.
  ///
  /// Throws a [CommandNotFoundException] if [message] did not match any command on [commands].
  ///
  /// You might also be interested in:
  /// - [createInteractionChatContext], for creating [ChatContext]s from interaction events.
  Future<MessageChatContext> createMessageChatContext(
    Message message,
    StringView contentView,
    String prefix,
  ) async {
    ChatCommand command = commands.getCommand(contentView) ?? (throw CommandNotFoundException(contentView));

    TextChannel channel = await message.channel.get() as TextChannel;
    User user = message.author as User;

    Guild? guild;
    Member? member;
    if (channel is GuildChannel) {
      guild = await (channel as GuildChannel).guild.get();
      member = await guild.members[user.id].get();
    }

    return MessageChatContext(
      commands: commands,
      guild: guild,
      channel: channel,
      member: member,
      user: user,
      command: command,
      client: message.manager.client as NyxxGateway,
      prefix: prefix,
      message: message,
      rawArguments: contentView.remaining,
    );
  }

  /// Create an [InteractionChatContext] from an [ApplicationCommandInteraction].
  ///
  /// [interaction] is the interaction that triggered the command and [command] is the command
  /// executed by the event.
  ///
  /// You might also be interested in:
  /// - [createMessageChatContext], for creating [ChatContext]s from message events.
  Future<InteractionChatContext> createInteractionChatContext(
    ApplicationCommandInteraction interaction,
    List<InteractionOption> options,
    ChatCommand command,
  ) async {
    Member? member = interaction.member;
    User user = member?.user ?? interaction.user!;

    Map<String, dynamic> rawArguments = <String, dynamic>{};

    for (final option in options) {
      rawArguments[option.name] = option.value;
    }

    return InteractionChatContext(
      commands: commands,
      guild: await interaction.guild?.get(),
      channel: await interaction.channel!.get() as TextChannel,
      member: member,
      user: user,
      command: command,
      client: interaction.manager.client as NyxxGateway,
      interaction: interaction,
      rawArguments: rawArguments,
    );
  }

  /// Create a [UserContext] from an [ApplicationCommandInteraction].
  ///
  /// [interaction] is the interaction event that triggered the command and [command] is the
  /// command executed by the event.
  Future<UserContext> createUserContext(
    ApplicationCommandInteraction interaction,
    UserCommand command,
  ) async {
    Member? member = interaction.member;
    User user = member?.user ?? interaction.user!;

    final client = interaction.manager.client as NyxxGateway;

    User targetUser = await client.users[interaction.data.targetId!].get();
    Guild? guild = await interaction.guild?.get();

    return UserContext(
      commands: commands,
      client: client,
      interaction: interaction,
      command: command,
      channel: await interaction.channel!.get() as TextChannel,
      member: member,
      user: user,
      guild: guild,
      targetUser: targetUser,
      targetMember: await guild?.members[targetUser.id].get(),
    );
  }

  /// Create a [MessageContext] from an [ApplicationCommandInteraction].
  ///
  /// [interaction] is the interaction event that triggered the command and [command] is the
  /// command executed by the event.
  Future<MessageContext> createMessageContext(
    ApplicationCommandInteraction interaction,
    MessageCommand command,
  ) async {
    Member? member = interaction.member;
    User user = member?.user ?? interaction.user!;

    Guild? guild = await interaction.guild?.get();

    TextChannel channel = await interaction.channel!.get() as TextChannel;

    return MessageContext(
      commands: commands,
      client: interaction.manager.client as NyxxGateway,
      interaction: interaction,
      command: command,
      channel: channel,
      member: member,
      user: user,
      guild: guild,
      targetMessage: await channel.messages[interaction.data.targetId!].get(),
    );
  }

  /// Create an [AutocompleteContext] from an [ApplicationCommandAutocompleteInteraction].
  ///
  /// [interaction] is the interaction event that triggered the autocomplete action and
  /// [command] is the command to which the autocompleted parameter belongs.
  Future<AutocompleteContext> createAutocompleteContext(
    ApplicationCommandAutocompleteInteraction interaction,
    ChatCommand command,
  ) async {
    Member? member = interaction.member;
    User user = member?.user ?? interaction.user!;

    Iterable<InteractionOption> expandOptions(List<InteractionOption> options) sync* {
      for (final option in options) {
        yield option;
        if (option.options case final nestedOptions?) {
          yield* expandOptions(nestedOptions);
        }
      }
    }

    final focusedOption = expandOptions(interaction.data.options!).singleWhere((element) => element.isFocused == true);

    return AutocompleteContext(
      commands: commands,
      guild: await interaction.guild?.get(),
      channel: await interaction.channel!.get() as TextChannel,
      member: member,
      user: user,
      command: command,
      client: interaction.manager.client as NyxxGateway,
      interaction: interaction,
      option: focusedOption,
      currentValue: focusedOption.value.toString(),
    );
  }

  /// Create a [ButtonComponentContext] from a [MessageComponentInteraction].
  ///
  /// [interaction] is the interaction event that triggered this context's creation.
  Future<ButtonComponentContext> createButtonComponentContext(
    MessageComponentInteraction interaction,
  ) async {
    Member? member = interaction.member;
    User user = member?.user ?? interaction.user!;

    return ButtonComponentContext(
      user: user,
      member: member,
      guild: await interaction.guild?.get(),
      channel: await interaction.channel!.get() as TextChannel,
      commands: commands,
      client: interaction.manager.client as NyxxGateway,
      interaction: interaction,
    );
  }

  /// Create a [SelectMenuContext] from a [MessageComponentInteraction].
  ///
  /// [interaction] is the interaction event that triggered this context's creation and
  /// [selected] is the value(s) that were selected by the user.
  Future<SelectMenuContext<T>> createSelectMenuContext<T>(
    MessageComponentInteraction interaction,
    T selected,
  ) async {
    Member? member = interaction.member;
    User user = member?.user ?? interaction.user!;

    return SelectMenuContext(
      user: user,
      member: member,
      guild: await interaction.guild?.get(),
      channel: await interaction.channel!.get() as TextChannel,
      commands: commands,
      client: interaction.manager.client as NyxxGateway,
      interaction: interaction,
      selected: selected,
    );
  }

  /// Create a [ModalContext] from a [ModalSubmitInteraction].
  ///
  /// [interaction] is the interaction event that triggered this context's creation.
  Future<ModalContext> createModalContext(ModalSubmitInteraction interaction) async {
    Member? member = interaction.member;
    User user = member?.user ?? interaction.user!;

    return ModalContext(
      user: user,
      member: member,
      guild: await interaction.guild?.get(),
      channel: await interaction.channel!.get() as TextChannel,
      commands: commands,
      client: interaction.manager.client as NyxxGateway,
      interaction: interaction,
    );
  }
}
