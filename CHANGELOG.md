## 3.0.0
__Breaking changes__:
- The base `Bot` class has been replaced with a `CommandsPlugin` class that can be used as a plugin with nyxx `3.0.0`
- `nyxx` and `nyxx_interactions` dependencies have been bumped to `3.0.0`; versions `2.x` are now unsupported
- `BotOptions` has been renamed to `CommandsOptions` and no longer supports the options found in `ClientOptions`. Create two seperate instances and pass them to `NyxxFactory.createNyxx...` and `CommandsPlugin` respectively, in the `options` named parameter
- The `bot` field on `Context` has been replaced with a `client` field pointing to the `INyxx` instance and a `commands` field pointing to the `CommandsPlugin` instance.

## 2.0.0:
__Breaking changes__:
- Messages sent by bot users will no longer be executed by default, see `BotOptions.acceptBotCommands` and `BotOptions.acceptSelfCommands`

__New features__:
- A new `acceptBotCommands` option has been added to `BotOptions` to allow executing commands from messages sent by other bot users
- A new `acceptSelfCommands` options has been added to `BotOptions` to allow executing commands from messages sent by the bot itself
- `onPreCall` and `onPostCall` streams on `Commands` and  `Groups` can be used to register pre- and post- call hooks
- `AbstractCheck` class can be exetended to implement stateful checks
- `CooldownCheck` can be used to apply a cooldown to a command based on different criteria
- `InteractionCheck` and `MessageCheck` can be used with `Check.any()` to allow slash commands or text commands to bypass other checks
- `Check.all()` can be used to group checks

__Bug fixes__:
- Invalid cased command/group/argument names are now caught and a `CommandRegistrationError` is thrown
- `StringView.escape()` now correctly escapes from `start` to `end` and not `start` to `index`

## 1.0.0
- *Version 1 was skipped to keep version consistent with the other nyxx libraries*

## 0.4.0
__Breaking changes__:
- Exceptions have been reworked and are no longer named the same

__New features__:
- Converters can now specify pre-defined choices for their type, this behaviour can be overridden on a per-command basis with the `@Choices` decorator
- Command arguments can now have custom names with the `@Name` decorator

## 0.3.0
__New features__:
- Checks now integrate with Discord's slash command permissions
- Checks can now be asynchronous
- Added `RoleCheck`, `UserCheck` and `GuildCheck` that represent the basic Discord slash command permissions: role restricted, user restricted and guild restricted (guild command)
- Slash command arguments can have descriptions set with the `@Description` decorator

__Breaking changes__:
- Checks are no longer a simple function

## 0.2.0
__Breaking changes__:
- Reorder `description` and `execute` parameters in `Command.textOnly` and `Command.slashOnly` constructors.
- Remove `syncDeleted` option from `BotOptions` as nyxx_interactions removes them on sync anyways.

__New features__:
- Add `send(MessageBuilder)` and `respond(MessageBuilder)` methods to `Context`
- Add `children` as an optional argument to `Command` and `Group` constructor
- Add `autoAcknowledgeInteractions` option to `BotOptions` to determine whether to automatically respond to interaction events
- Commands can now restrict execution using checks

__Bugfixes__:
- `InteractionContext.respond` will no longer throw an error when responding immediately
- Slash Commands can no longer have direct slash command children
- Errors emitted outside of argument parsing and callback execution are now correctly sent to `Bot.onCommandError`

__Miscellaneous__:
- Text-only and slash-only commands can now have `Context` as their first argument type

## 0.1.0

- Initial release