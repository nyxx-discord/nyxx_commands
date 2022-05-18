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

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands.dart';
import '../commands/chat_command.dart';
import 'context.dart';
import 'interaction_context.dart';

/// Represents a context in which an autocomplete event was triggered.
class AutocompleteContext implements IContextBase, IInteractionContextBase {
  @override
  final CommandsPlugin commands;

  @override
  final IGuild? guild;

  @override
  final ITextChannel channel;

  @override
  final IMember? member;

  @override
  final IUser user;

  @override
  final ChatCommand command;

  @override
  final INyxx client;

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

  /// Create a new [AutocompleteContext].
  AutocompleteContext({
    required this.commands,
    required this.guild,
    required this.channel,
    required this.member,
    required this.user,
    required this.command,
    required this.client,
    required this.interaction,
    required this.interactionEvent,
    required this.option,
    required this.currentValue,
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
