## 4.0.0-dev.2.0
__Breaking changes__:
- Upgrade to `nyxx_interactions` 4.0.0

__Bug fixes__
- Fix `UserCommandCheck` always failing.
- Fix parsing muultiple arguments at once leading to race conditions.
- Fix a casting error that occurred when a text command was not found.

__Documentation__:
- The documentation for the entire package has been rewritten, with examples, references and more. See the documentation for more details.

__New features__:
- Added support for the `attachment` command option type. Use `IAttachment` (from `nyxx_interactions`) as the argument type in your commands callback for `nyxx_commands` to register it as an attachment command option.
- Added `IInteractionContext`, an interface implemented by all contexts originating from intetractions.

## 4.0.0-dev.1.2
__Bug fixes__:
- Fixed a bug affecting command syncing with external sharding.

## 4.0.0-dev.1.1
__Bug fixes__:
- Fixed a bug affecting registration of slash commands nested two layers deep.

## 4.0.0-dev.1
__New features__:
- Export the command types for better typing. See the documentation for `ICallHooked`, `IChatCommandComponent`, `IChecked`, `ICommand`, `ICommandGroup`, `ICommandRegisterable` and `IOptions` for more information.
- Add new checks for allowing certain checks to be bypassed by certain command types. See the documentation for `ChatCommandCheck`, `InteractionCommandCheck`, `InterationChatCommandCheck`, `MessageChatCommandCheck`, `MessageCommandCheck` and `UserCommandCheck` for more info.
- Export `registerDefaultConverters` and `parse` for users wanting to implement their own commands plugin.

## 4.0.0-dev.0
__Breaking changes__:
- The names of command classes have changed. The old class `Command` is now named `ChatCommand` and `Group` is now `ChatGroup`.
- The names of context classes have changed. The old class `Context` is now named `IChatContext`, `MessageContext` is `MessageChatContext` and `InteractionContext` is now `InteractionChatContext`.
- All deprecated members have been removed.
- The `hideOriginalResponse` parameter has been removed from the `ChatCommand` constructor. Use the new `options` parameter and specify `hideOriginalResponse` there instead.

If you find any more breaking changes please notify us on the official nyxx Discord server, or open an issue on GitHub.

__New features__:
- Support for User Application Commands has been addded. They can be created through the `UserCommand` class similarly to `ChatCommand`s, and must be added with `CommandsPlugin.addCommand()` as `ChatCommand`s are.
- Support for Message Application Commands has been addded. They can be created through the `MessageCommand` class similarly to `ChatCommand`s, and must be added with `CommandsPlugin.addCommand()` as `ChatCommand`s are.
- Better support for command configuration has been added. Users can now specify options to apply only to specific commands through the `options` parameter in all command constructors with the new `CommandOptions` class. Similarly to checks, these options are inherited but can be overridden by children.
- Added a few simple functions for easier interaction with `nyxx_interactions` covering common use cases for interactions.

__Bug fixes__:
- Fixed an edge case issue with converters where assembled converters sometimes wouldn't return the correct type

## 3.3.0
__New features__:
- Added a `remaining()` method to `CooldownCheck` to get the remaining cooldown for a context.

__Deprecations__:
- `registerChild` has been deprecated, users should prefer the better named `addCommand` method.

## 3.2.0
__Bug fixes__:
- Exceptions are now correctly caught for commands with async `execute` functions.
- Check hooks are now correctly called when using `Check.all`, `Check.any` or `Check.deny`.

__New features__:
- Added a new `private` option to `Context.respond` that allows users to send private responses to commands.
- Added the ability to combine `CooldownTypes` using the binary OR (`|`) operator.
- Added a new `dmOr` function that can be used in `CommandsPlugin.prefix` to allow users to omit the bot prefix in DMs.

## 3.1.1
__Bug fixes__:
- Fixed an issue where `Check.all`, `Check.any` and `Check.deny` would not accept `AbstractCheck`s as arguments.

## 3.1.0
__New features__:
- Default choices for `CombineConverter`s and `FallbackConverter`s can now be specified in the `choices` parameter.
- You can now specify the Discord slash command option type to use in `Converter`, `CombineConverter` and `FallbackConverter`s with the `type` parameter.
- Added a new `hideOriginalResponse` option to `CommandsOptions` that allows you to hide the automatic acknowledgement of interactions with `autoAcknowledgeInteractions`.
- Added a new `acknowledge` method to `InteractionContext` that allows you to override `hideOriginalResponse`.
- Added a new `hideOriginalResponse` parameter to `Command` constructors that allows you to override `CommandsOptions.hideOriginalResponse` on a per-command basis.
- Added a new `hidden` parameter to `InteractionContext.respond` that allows you to send an ephemeral response. The hidden state of the response sent is guaranteed to match the `hidden` parameter, however to avoid strange behaviour it is recommended to acknowledge the interaction with `InteractionContext.acknowledge` if the response is delayed.
- Added a new `mention` parameter to `MessageContext.respond` that allows you to specify whether the reply to the command should mention the user or not.
- Added a new `UseConverter` decorator that allows you to override the converter used to parse a specific argument.
- Added converters for `double`s and `Mentionable`s.
- Added a new global `mentionOr` function that can be used in `CommandsPlugin.prefix` to allow mention prefixes.

__Miscellaneous__:
- `autoAcknowledgeInteractions` no longer immediately acknowledges interactions upon receiving them, allowing ephemeral responses to be correctly sent.
- Bumped `nyxx_interactions` to 3.1.0
- Argument parsing is now done in parallel, making commands with multiple arguments faster to invoke.

__Deprecations__:
- Setting the Discord slash command option type to use for a Dart `Type` via the `discordTypes` map is now deprecated. Use the `type` parameter in converter consutrctors instead.
- `Context.send` is now deprecated as `Context.respond` is more appropriate for most cases. If `Context.send` was really what you wanted, use `Context.channel.sendMessage` instead.

## 3.0.0
__Breaking changes__:
- The base `Bot` class has been replaced with a `CommandsPlugin` class that can be used as a plugin with nyxx `3.0.0`.
- `nyxx` and `nyxx_interactions` dependencies have been bumped to `3.0.0`; versions `2.x` are now unsupported.
- `BotOptions` has been renamed to `CommandsOptions` and no longer supports the options found in `ClientOptions`. Create two seperate instances and pass them to `NyxxFactory.createNyxx...` and `CommandsPlugin` respectively, in the `options` named parameter.
- The `bot` field on `Context` has been replaced with a `client` field pointing to the `INyxx` instance and a `commands` field pointing to the `CommandsPlugin` instance.

## 2.0.0
__Breaking changes__:
- Messages sent by bot users will no longer be executed by default, see `BotOptions.acceptBotCommands` and `BotOptions.acceptSelfCommands`.

__New features__:
- A new `acceptBotCommands` option has been added to `BotOptions` to allow executing commands from messages sent by other bot users.
- A new `acceptSelfCommands` options has been added to `BotOptions` to allow executing commands from messages sent by the bot itself.
- `onPreCall` and `onPostCall` streams on `Commands` and  `Groups` can be used to register pre- and post- call hooks.
- `AbstractCheck` class can be exetended to implement stateful checks.
- `CooldownCheck` can be used to apply a cooldown to a command based on different criteria.
- `InteractionCheck` and `MessageCheck` can be used with `Check.any()` to allow slash commands or text commands to bypass other checks.
- `Check.all()` can be used to group checks.

__Bug fixes__:
- Invalid cased command/group/argument names are now caught and a `CommandRegistrationError` is thrown.
- `StringView.escape()` now correctly escapes from `start` to `end` and not `start` to `index`.

## 1.0.0
- *Version 1 was skipped to keep version consistent with the other nyxx libraries*.

## 0.4.0
__Breaking changes__:
- Exceptions have been reworked and are no longer named the same.

__New features__:
- Converters can now specify pre-defined choices for their type, this behaviour can be overridden on a per-command basis with the `@Choices` decorator.
- Command arguments can now have custom names with the `@Name` decorator.

## 0.3.0
__New features__:
- Checks now integrate with Discord's slash command permissions.
- Checks can now be asynchronous.
- Added `RoleCheck`, `UserCheck` and `GuildCheck` that represent the basic Discord slash command permissions: role restricted, user restricted and guild restricted (guild command).
- Slash command arguments can have descriptions set with the `@Description` decorator.

__Breaking changes__:
- Checks are no longer a simple function.

## 0.2.0
__Breaking changes__:
- Reorder `description` and `execute` parameters in `Command.textOnly` and `Command.slashOnly` constructors.
- Remove `syncDeleted` option from `BotOptions` as nyxx_interactions removes them on sync anyways.

__New features__:
- Add `send(MessageBuilder)` and `respond(MessageBuilder)` methods to `Context`.
- Add `children` as an optional argument to `Command` and `Group` constructor.
- Add `autoAcknowledgeInteractions` option to `BotOptions` to determine whether to automatically respond to interaction events.
- Commands can now restrict execution using checks.

__Bugfixes__:
- `InteractionContext.respond` will no longer throw an error when responding immediately.
- Slash Commands can no longer have direct slash command children.
- Errors emitted outside of argument parsing and callback execution are now correctly sent to `Bot.onCommandError`.

__Miscellaneous__:
- Text-only and slash-only commands can now have `Context` as their first argument type.

## 0.1.0

- Initial release.
