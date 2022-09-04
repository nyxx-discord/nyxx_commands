import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands/chat_command.dart';
import 'base.dart';

/// Represents a context in which an autocomplete event was triggered.
class AutocompleteContext extends ContextBase implements IInteractionContextData {
  @override
  final ISlashCommandInteraction interaction;

  @override
  final IAutocompleteInteractionEvent interactionEvent;

  /// The option that the user is currently filling in.
  ///
  /// Other options might have already been filled in and are accessible through [interactionEvent].
  final IInteractionOption option;

  /// The value the user has put in [option] so far.
  ///
  /// This can be empty. It will generally not contain malformed data, but care should still be
  /// taken. Read [the official documentation](https://discord.com/developers/docs/interactions/application-commands#autocomplete)
  /// for more.
  final String currentValue;

  /// A map containing the arguments and the values that the user has inputted so far.
  ///
  /// The keys of this map depend on the names of the arguments set in [command]. If a user has not
  /// yet filled in an argument, it will not be present in this map.
  ///
  /// The values might contain partial data.
  late final Map<String, String> existingArguments = Map.fromEntries(
    interactionEvent.options.map((option) => MapEntry(option.name, option.value.toString())),
  );

  /// A map containing the arguments of [command] and their value, if the user has inputted a value
  /// for them.
  ///
  /// The keys of this map depend on the names of the arguments set in [command].
  ///
  /// The values might contain partial data.
  late final Map<String, String?> arguments;

  final ChatCommand command;

  AutocompleteContext({
    required this.command,
    required this.interaction,
    required this.interactionEvent,
    required this.option,
    required this.currentValue,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  }) {
    ISlashCommand command = commands.interactions.commands.singleWhere(
      (command) => command.id == interaction.commandId,
    );

    arguments = Map.fromIterable(
      command.options.map((option) => option.name),
      value: (option) => existingArguments[option],
    );
  }

  /// Whether the user has inputted a value for an argument with the name [name].
  bool hasArgument(String name) => existingArguments.containsKey(name);
}
