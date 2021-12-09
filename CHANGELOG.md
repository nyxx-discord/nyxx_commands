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