## 6.0.2
__Bug fixes__
- Fixed autocompletion in commands in chat groups

## 6.0.1
__Bug fixes__
- Fixed ephemeral response levels breaking component helpers.
- Fixed `getMultiSelection` not working.
- `CommandsPlugin.guild` is not longer ignored.

## 6.0.0
__Breaking changes__
- Update nyxx to version 6.0.0.

__Bug fixes__
- Fixes a type error that could occur when using FallbackConverter's toButton and toMultiselect.

## 6.0.0-dev.1
__Breaking changes__
- Update nyxx to version 6.0.0. See the changelog at https://pub.dev/packages/nyxx for more details.

## 5.0.2
__Bug fixes__
- Fix disposing the plugin partway through command execution causing errors.

## 5.0.1
__Bug fixes__
- Fix component timeouts triggering instantly.
- Fix component wrappers causing null assertions to trigger.

## 5.0.0
__Breaking changes__
- Removed all deprecated APIs.
- APIs which used to take `Type` objects now take `RuntimeType`s for the relevant type.
- APIs which used to take the `customId` of a component now take a `ComponentId`.
- Context types have been reorganized. See the docs for `IContextData`, `ICommandContext` and `IInteractiveContext` for more.
- Converter & check APIs now take `IContextData` objects instead of `IContext` objects.
- Checks now use named parameters instead of positional ones in their constructors.
- `IInteractiveContext.respond` (formerly `IContext.respond`) now takes a `ResponseLevel` object instead of `private` and `hidden`.
- The `interactions` field on `CommandsPlugin` is now nullable to avoid a `late` modifier. Use `IContextData.interactions` instead for a non nullable field.

__New features__
- Contexts are now managed by a `ContextManager` which allows users to create their own contexts.
- Added support for modal helpers. See `IInteractionInteractiveContext.getModal` for more.
- Added new errors: `ConverterFailedException`, `InteractionTimeoutException`, `UncaughtCommandsException` and `UnhandledInteractionException`.
- Events & listeners are now handled by an `EventManager` and `ComponentId`s.
- Prefix callbacks can now be asynchronous and return any `Pattern`.
- Added `autoAcknowledgeDuration` for more control over auto-acknowledge.
- Added parsing utilities on `AutocompleteContext` for parsing arguments.
- Contexts in a command are now chained, so interaction expiry and inconsistent formatting of responses to commands are no longer an issue. See `IInteractiveContext.delegate` for more.
- Added many helpers for handling message components:
  - `awaitButtonPress`, `awaitSelection` and `awaitMultiSelection` for using fully custom components with nyxx_commands;
  - `getButtonPress`, `getButtonSelection` and `getConfirmation` for handling buttons;
  - `getSelection` and `getMultiSelection` for handling multiselect menus.
- Added `SimpleConverter` to simplify creating custom converters.
- The prefix callback can now be set to null to disable message commands. This will change the default command type to `slashOnly` unless `CommandsOptions.inferDefaultCommandType` is set to `false`.
- Added `skipPattern` to `StringView`, similar to `skipString`.

__Bug fixes__
- Fixed a bug that prevented `part` files from being compiled.
- Fixed a bug that prevented enum parameters from being compiled.
- Fixed nested command `fullName`s not being correct.

__Miscellaneous__
- Optimized the compilation script to generate less code and use a more reliable subtype checking method.
- Instructions for compilation can now be found at the package README.
- Bump `nyxx` to 5.0.0 and `nyxx_interactions` to 4.6.0.

## 5.0.0-dev.3
__Bug fixes__
- Fixed a bug which caused `IInteractiveContext.respond` to error after auto-acknowledge.
- Fixed a bug where `getSelection` and `getMultiSelection` would result in an "Interaction failed" error, despite the response being sent.
- Fixed a bug that caused a late initialization error to occur if an error occurred in `respond`.
- Fixed `getSelection` sending a new message for different pages instead of editing the same message.

## 5.0.0-dev.2
__Breaking changes__
- The `DartType` class introduced in 5.0.0-dev.0 has been replaced with `RuntimeType` from [`package:runtime_type`](https://pub.dev/packages/runtime_type).
- All errors thrown by command callbacks are now caught instead of only subclasses of `Exception`. The relevant fields on `UncaughtException` and `AutocompleteFailedException` have therefore been changed from `Exception` to `Object`.
- APIs that took a combination of user, timeout and component id have been changed to use the new `ComponentId` class.

__New features__
- Errors will now be added to `CommandsPlugin.onCommandError` when a message component created by nyxx_commands enters an invalid state (e.g no handler found or the user was not allowed to use the component). See the docs for `UnhandledInteractionException` for more.
- Added `ComponentId` as a way for nyxx_commands to generate an ID for message components that contains information about the component's state in nyxx_commands.
- Added a new `InteractionTimeoutException` thrown when an interaction times out instead of Dart's `TimeoutException`.
- Added a `stackTrace` getter to all `CommandsExceptions`.

__Bug fixes__
- Fixed an issue where enum values in annotations caused the compiler to crash.

__Miscellaneous__
- Added documentation with instructions on how to compile nyxx_commands to the README.
- Correctly export `ContextManager`.
- Changed the log message for uncaught exceptions. The message no longer contains the error description, instead passing the error object through the log record's error field. Versions of nyxx after 4.5.0 contain a `Logging` plugin that will display this error for you.

## 5.0.0-dev.1
__Breaking changes__:
- `CommandsPlugin` has been made more type safe, making the `interactions` field nullable. To use the `IInteractions` instance from your commands, see `IContextData.interactions`. `client` has also been changed to be read-only.

__New features__:
- A helper for using modals has been added. See `IInteractionInteractiveContext.getModal` for more.
- `getSelection` and `getMultiSelection` from `IInteractiveContext` can now be used without a converter, using the `toMultiSelect` parameter.
- Failed converters now throw a `ConverterFailedException` instead of a `BadInputException`.
- `SimpleConverter.provider` can now be async.

__Bug fixes__:
- `IChatCommandComponent.fullName` now correctly returns the full command name.
- Responding to a component context now correctly clears components on the message.

__Miscellaneous__:
- `package:analyzer` has been bumped to 5.0.0.
- A few elements that were previously unexported are now correctly exported.

## 5.0.0-dev.0
__Breaking changes__:
- `ChatCommand.type` has been moved to `CommandOptions`. Use `ChatCommand(options: CommandOptions(type: ...))` instead  of `ChatCommand(type: ...)` to set a commands type. With this change, the `textOnly` and `slashOnly` constructors have been removed from `ChatCommand`.
- `Converter`s no longer take an `IContext` as a parameter but now take an `ICommandContextData`.
- Some of the arguments in `Check` constructors have been changed from positional to named arguments.
- All deprecated fields have been removed.
- `IInteractiveContext.respond` (previously `IContext.respond`) now takes a `ResponseLevel` instead of the context-type-specific named parameters. See `ResponseLevel` for more.
- All uses of `Type`s in the package have been replaced with `DartType`s. This wrapper class allows for sound type safety and simplifies compilation. Notable places this change has an effect are in `CommandsPlugin.getConverter` and `NoConverterException.type`.
- The old component wrappers have been replaced with newer, more versatile methods.

__New features__:
- The `prefix` function used to determine the prefix for a given text message can now return a `Pattern` and be asynchronous. This allows the use of `RegExp`s to determine command prefixes.
- `CommandsPlugin.contextManager` can be used to create your own contexts from raw events.
- `SimpleConverter` is a new `Converter` that simplifies the creation of custom converters. Providing a function to generate items and a function to stringify each item will create a converter with support for basic conversion, autocompletion and more.
- The prefix is now nullable in the `CommandsPlugin` constructor. Setting it to `null` will make the default command type automatically be `slashOnly` if `CommandsOptions.inferDefaultCommandType` is `true`.
- Commands will now respond to the latest interaction instead of the original interaction if the component wrappers on `IInteractiveContext` are used. See `IInteractiveContext.delegate` for more.
- `CommandOptions.preserveComponentMessages` can be used to choose whether Message Component responses should overwrite the message.
- `CommandOptions.autoAcknowledgeDuration` can be used to manually set the auto-acknowledge timeout.
- `CommandOptions.caseInsensitiveCommands` can be used to allow commands to be invoked case-insensitively.
- `AutocompleteContext` has new methods for parsing values in the autocompletion event.

__Bug fixes__:
- Returning `null` in an autocomplete handler no longer displays an error in the Discord UI.

## 4.4.1
__Bug fixes__:
- Fix `part` directives breaking compilation.

## 4.4.0
__Miscellaneous__:
- Bump `analyzer` to 5.7.1, `args` to 2.4.0, `dart_style` to 2.2.5, `logging` to 1.1.1, `meta` to 1.9.0, `nyxx` to 4.5.0, `nyxx_interactions` to 4.5.0, `path` to 1.8.3 `build_runner` to 2.1.0, `coverage` to 1.6.3, `lints` to 2.0.1, `mockito` to 5.3.2, and `test` to 1.23.1.

## 4.3.0
__New features__:
- Added support for command localization. See `localizedNames` on all `ICommand`s and `localizedDescriptions` for `ChatCommand`s and the `@Description()` annotation.

__Bug fixes__:
- Fixes `@Name` annotations not working when running with `dart:mirrors`.
- Fixes the plugin not correctly disposing when the client is disposed.
- Fixed the automatic response sometimes failing.

__Miscellaneous__:
- Bump `nyxx` to 4.0.0 and `nyxx_interactions` to 4.3.1.

## 4.2.0
__New features__:
- Added a script which allows `nyxx_commands` to be compiled. For more information, run `dart pub global activate nyxx_commands` and `nyxx-compile --help`.
- Implemented support for permissions V2. See `PermissionsCheck` for more.

__Deprecations__:
- Deprecated `AbstractCheck.permissions` and all associated features.

## 4.2.0-dev.1
__New features__:
- Added a script which allows `nyxx_commands` to be compiled. For more information, run `dart pub global activate nyxx_commands` and `nyxx-compile --help`.

## 4.2.0-dev.0
__Deprecations__:
- Deprecated `AbstractCheck.permissions` and all associated features.

__New features__:
- Added `AbstractCheck.allowsDm` and `AbstractCheck.requiredPermissions` for integrating checks with permissions v2.
- Updated `Check.deny`, `Check.any` and `Check.all` to work with permissions v2.
- Added `PermissionsCheck`, for checking if users have a specific permission.

__Miscellaneous__:
- Bump `nyxx_interactions` to 4.2.0.
- Added proper names to context type checks if none is provided.

## 4.1.2
__Bug fixes__:
- Fixes an issue where slash commands nested within text-only commands would not be registered

## 4.1.1
__Bug fixes__:
- Correctly export the `@Autocomplete(...)` annotation.

## 4.1.0
__New features__:
- Support for autocompletion has been added. See `Converter.autocompleteCallback` and the `@Autocomplete(...)` annotation for more.
- Added the ability to allow only slash commands or disable them entirely. See `CommandType.def` and `CommandOptions.defaultCommandType` for more.
- Added `ChatCommand.argumentTypes`, which allows developers to access the argument types for a chat command callback.
- Added `Converter.processOptionCallback`, which allows developers to modify the builder generated for a command argument.
- Added `IntConverter`, `DoubleConverter` and `NumConverter` for converting numbers with custom bounds. These new classes allow you to specify a minimum and maximum value for an argument when used with `@UseConverter(...)`.
- Added `GUildChannelConverter` for converting more specific types of guild channels.

__Bug fixes__:
- Fixed an issue with `IContext.getButtonPress` not behaving correctly when `authorOnly` or `timeout` was specified.
- Fixed the default converters for guild channels accepting all channels in the Discord UI even if they were not the correct type.

__Miscellaneous__:
- Updated the command name validation regex.
- Bump `nyxx_interactions` to 4.1.0.

## 4.0.0
__Breaking changes__:
- `nyxx_interactions` has been upgraded to 4.0.0.
- The names of command classes have changed. The old class `Command` is now named `ChatCommand` and `Group` is now `ChatGroup`.
- The names of context classes have changed. The old class `Context` is now named `IChatContext`, `MessageContext` is `MessageChatContext` and `InteractionContext` is now `InteractionChatContext`.
- All deprecated members have been removed.
- The `hideOriginalResponse` parameter has been removed from the `ChatCommand` constructor. Use the new `options` parameter and specify `hideOriginalResponse` there instead.

__New features__:
- Added support for User and Message Application Commands. See the docs for `UserCommand` and `MessageCommand` for more information.
- Added new in-built checks for validating content types.
- Added helper methods for using `nyxx_interactions` with `nyxx_commands`.
- Added support for the attachment command option type. Use the `IAttachment` type as your command callback parameter type to use the appropriate converter.

__Documentation__:
- The documentation for the entire package has been rewritten, with examples, references and more. See the documentation for more details.

__Bug fixes__:
- Fix a bug concerning optional arguments having their default values wrapped in futures.

## 4.0.0-dev.2.1
__Bug fixes__:
- Fix a bug concerning types that didn't need to be converted being wrapped in Futures.

## 4.0.0-dev.2.0
__Breaking changes__:
- Upgrade to `nyxx_interactions` 4.0.0.

__Bug fixes__
- Fix `UserCommandCheck` always failing.
- Fix parsing multiple arguments at once leading to race conditions.
- Fix a casting error that occurred when a text command was not found.

__Documentation__:
- The documentation for the entire package has been rewritten, with examples, references and more. See the documentation for more details.

__New features__:
- Added support for the `attachment` command option type. Use `IAttachment` (from `nyxx_interactions`) as the argument type in your commands callback for `nyxx_commands` to register it as an attachment command option.
- Added `IInteractionContext`, an interface implemented by all contexts originating from interactions.

## 4.0.0-dev.1.2
__Bug fixes__:
- Fixed a bug affecting command syncing with external sharding.

## 4.0.0-dev.1.1
__Bug fixes__:
- Fixed a bug affecting registration of slash commands nested two layers deep.

## 4.0.0-dev.1
__New features__:
- Export the command types for better typing. See the documentation for `ICallHooked`, `IChatCommandComponent`, `IChecked`, `ICommand`, `ICommandGroup`, `ICommandRegisterable` and `IOptions` for more information.
- Add new checks for allowing certain checks to be bypassed by certain command types. See the documentation for `ChatCommandCheck`, `InteractionCommandCheck`, `InteractionChatCommandCheck`, `MessageChatCommandCheck`, `MessageCommandCheck` and `UserCommandCheck` for more info.
- Export `registerDefaultConverters` and `parse` for users wanting to implement their own commands plugin.

## 4.0.0-dev.0
__Breaking changes__:
- The names of command classes have changed. The old class `Command` is now named `ChatCommand` and `Group` is now `ChatGroup`.
- The names of context classes have changed. The old class `Context` is now named `IChatContext`, `MessageContext` is `MessageChatContext` and `InteractionContext` is now `InteractionChatContext`.
- All deprecated members have been removed.
- The `hideOriginalResponse` parameter has been removed from the `ChatCommand` constructor. Use the new `options` parameter and specify `hideOriginalResponse` there instead.

If you find any more breaking changes please notify us on the official nyxx Discord server, or open an issue on GitHub.

__New features__:
- Support for User Application Commands has been added. They can be created through the `UserCommand` class similarly to `ChatCommand`s, and must be added with `CommandsPlugin.addCommand()` as `ChatCommand`s are.
- Support for Message Application Commands has been added. They can be created through the `MessageCommand` class similarly to `ChatCommand`s, and must be added with `CommandsPlugin.addCommand()` as `ChatCommand`s are.
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
- Added a new `hidden` parameter to `InteractionContext.respond` that allows you to send an ephemeral response. The hidden state of the response sent is guaranteed to match the `hidden` parameter, however to avoid strange behavior it is recommended to acknowledge the interaction with `InteractionContext.acknowledge` if the response is delayed.
- Added a new `mention` parameter to `MessageContext.respond` that allows you to specify whether the reply to the command should mention the user or not.
- Added a new `UseConverter` decorator that allows you to override the converter used to parse a specific argument.
- Added converters for `double`s and `Mentionable`s.
- Added a new global `mentionOr` function that can be used in `CommandsPlugin.prefix` to allow mention prefixes.

__Miscellaneous__:
- `autoAcknowledgeInteractions` no longer immediately acknowledges interactions upon receiving them, allowing ephemeral responses to be correctly sent.
- Bumped `nyxx_interactions` to 3.1.0
- Argument parsing is now done in parallel, making commands with multiple arguments faster to invoke.

__Deprecations__:
- Setting the Discord slash command option type to use for a Dart `Type` via the `discordTypes` map is now deprecated. Use the `type` parameter in converter constructors instead.
- `Context.send` is now deprecated as `Context.respond` is more appropriate for most cases. If `Context.send` was really what you wanted, use `Context.channel.sendMessage` instead.

## 3.0.0
__Breaking changes__:
- The base `Bot` class has been replaced with a `CommandsPlugin` class that can be used as a plugin with nyxx `3.0.0`.
- `nyxx` and `nyxx_interactions` dependencies have been bumped to `3.0.0`; versions `2.x` are now unsupported.
- `BotOptions` has been renamed to `CommandsOptions` and no longer supports the options found in `ClientOptions`. Create two separate instances and pass them to `NyxxFactory.createNyxx...` and `CommandsPlugin` respectively, in the `options` named parameter.
- The `bot` field on `Context` has been replaced with a `client` field pointing to the `INyxx` instance and a `commands` field pointing to the `CommandsPlugin` instance.

## 2.0.0
__Breaking changes__:
- Messages sent by bot users will no longer be executed by default, see `BotOptions.acceptBotCommands` and `BotOptions.acceptSelfCommands`.

__New features__:
- A new `acceptBotCommands` option has been added to `BotOptions` to allow executing commands from messages sent by other bot users.
- A new `acceptSelfCommands` options has been added to `BotOptions` to allow executing commands from messages sent by the bot itself.
- `onPreCall` and `onPostCall` streams on `Commands` and  `Groups` can be used to register pre- and post- call hooks.
- `AbstractCheck` class can be extended to implement stateful checks.
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
- Converters can now specify pre-defined choices for their type, this behavior can be overridden on a per-command basis with the `@Choices` decorator.
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
