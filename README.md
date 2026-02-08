# nyxx_commands

nyxx_commands is a framework for easily creating slash commands and text commands for Discord using the [nyxx](https://pub.dev/packages/nyxx) library.

Inspired by [discord.py](https://discordpy.readthedocs.io/en/stable/)'s [commands](https://discordpy.readthedocs.io/en/stable/ext/commands/index.html) extension.

Need help with nyxx_commands? Join our [Discord server](https://discord.gg/nyxx) and ask in the `#nyxx_commands` channel.

## Features
- Easy command creation
- Automatic compatibility with Discord slash commands
- Compatibility with the [nyxx](https://pub.dev/packages/nyxx) library
- Argument parsing

## Compiling nyxx_commands

If you compile a bot using nyxx_commands with `dart compile exe`, you might get an error you hadn't seen during development:
```
Error: Function data was not correctly loaded. Did you compile the wrong file?
Stack trace:
#0      loadFunctionData (package:nyxx_commands/src/mirror_utils/compiled.dart:10)
#1      ChatCommand._loadArguments (package:nyxx_commands/src/commands/chat_command.dart:354)
...
```

This is because nyxx_commands uses `dart:mirrors` to load the arguments for your commands. During development this is fine but this functionality breaks when compiled because [`dart:mirrors` cannot be used in compiled Dart programs](https://api.dart.dev/dart-mirrors/dart-mirrors-library.html#status-unstable).

To mitigate this, nyxx_commands provides a script that compiles your code for you and loads this information for nyxx_commands to use. To use it, you must first wrap all your command callbacks in [`id`](https://pub.dev/documentation/nyxx_commands/latest/nyxx_commands/id.html) and give each function a unique id.


For example, this chat command:
```dart
final ping = ChatCommand(
  'ping',
  'Ping the bot',
  (IChatContext context) => context.respond(MessageBuilder.content('Pong!')),
);
```
must have its callback wrapped with `id` like so:
```dart
final ping = ChatCommand(
  'ping',
  'Ping the bot',
  id('ping', (IChatContext context) => context.respond(MessageBuilder.content('Pong!'))),
);
```

You can also use a named function, provided that function is a top-level function declared in the same file:
```dart
final ping = ChatCommand(
  'ping',
  'Ping the bot',
  id('ping', _ping),
);

void _ping(IChatContext context) =>
  context.respond(MessageBuilder.content('Pong!'));
```

If you forget to add the `id` to a function, you'll get an error similar to this one:
```
Error: Command Exception: Couldn't load function data for function Closure: (IChatContext) => Null
Stack trace:
#0      loadFunctionData (package:nyxx_commands/src/mirror_utils/compiled.dart:18)
#1      ChatCommand._loadArguments (package:nyxx_commands/src/commands/chat_command.dart:354)
...
```

Once you've added `id` to all your commands, use the `nyxx_commands:compile` script to compile your program. See `dart run nyxx_commands:compile --help` for a list of options.

If you use the `--no-compile` flag, make sure that you run/compile the generated file and not your own main file.
