# Nyxx commands

Nyxx commands is a framework for easily creating slash commands and text commands for Discord using the [nyxx](https://pub.dev/packages/nyxx) library.

Insipred by [discord.py](https://discordpy.readthedocs.io/en/stable/)'s [commands](https://discordpy.readthedocs.io/en/stable/ext/commands/index.html) extension.

## Features
- Easy command creation
- Automatic compatibility with Discord slash commands
- Compatibility with the [nyxx](https://pub.dev/packages/nyxx) library
- Argument parsing

## Quick start

Create a bot:
```dart
Bot bot = new Bot(
  '<token>',
  GatewayIntents.allUnprivileged,
  prefix: '!',
  guild: Snowflake('<guild id>'), // Omit if you want commands to be registered globally
);
```

Create and register a simple command:
```dart
Command command = Command(
  'hi', // Command name
  'A simple command', // Command description
  (Context context, String name) async { // Command syntax and callback
    await context.channel.sendMessage(MessageBuilder.content('Hello, $name!');
  },
);

bot.registerChild(command);
```

Use a custom type converter:
```dart
Command command = Command(
  'pet',
  'A command with a type converter',
  (Context context, bool hasCat  /* User input will automatically be converted */) async {
    if (hasCat) {
        await context.channel.sendMessage(MessageBuilder.content('I have a cat.'));
    } else {
        await context.channel.sendMessage(MessageBuilder.content('I do not have any pets.'));
    }
  },
);
```

Use an optional argument:
```dart
Command command = Command(
  'sayhi',
  'A command with an optional argument',
  (Context context, String name, [String? familyName /* This parameter is optional. Notice that optional parameters are *not* named parameters! */]) async {
      await context.channel.sendMessage(MessageBuilder.content('My name is $name ${familyName ?? ""}'));
  },
);

// Also notice how the name "familyName" was converted to "family-name" in the registered slash command,
// this is to ensure discord accepts the parameter name.
```

Use a command group:
```dart
Group group = Group(
  'say',
  'An example group',
);

// Register commands to the group and not to the bot
group.registerChild(Command(
  'hi',
  'Say hi',
  (Context context) async {
    await context.channel.sendMessage(MessageBuilder.content('Hi!'));
  },
));

group.registerChild(Command(
  'goodbye',
  'Say goodbye',
  (Context context) async {
    await context.channel.sendMessage(MessageBuilder.content('Goodbye :('));
  },
));

// Register the group to the bot
bot.registerChild(group);
```
