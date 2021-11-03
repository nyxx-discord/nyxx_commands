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