// This is a file containing a "clean" version of example.dart, with comments stripped for
// readability.
// This file is generated automatically by scripts/generate_clean_example and should not be edited
// manually; edit example.dart and run scripts/generate_clean_example.

import 'package:nyxx/nyxx.dart';

import 'package:nyxx_commands/nyxx_commands.dart';

import 'dart:io';
import 'dart:math';

void main() async {
  CommandsPlugin commands = CommandsPlugin(
    prefix: (message) => '!',
    guild: Snowflake.parse(Platform.environment['GUILD']!),
    options: CommandsOptions(
      logErrors: true,
    ),
  );

  await Nyxx.connectGateway(
    Platform.environment['TOKEN']!,
    GatewayIntents.allUnprivileged | GatewayIntents.guildMembers,
    options: GatewayClientOptions(plugins: [commands, logging, cliIntegration, ignoreExceptions]),
  );

  ChatCommand ping = ChatCommand(
    'ping',
    'Checks if the bot is online',
    id('ping', (ChatContext context) {
      context.respond(MessageBuilder(content: 'pong!'));
    }),
  );

  commands.addCommand(ping);

  ChatGroup throwGroup = ChatGroup(
    'throw',
    'Throw an objet',
    children: [
      ChatCommand(
        'coin',
        'Throw a coin',
        id('throw-coin', (ChatContext context) {
          bool heads = Random().nextBool();

          context.respond(
              MessageBuilder(content: 'The coin landed on its ${heads ? 'head' : 'tail'}!'));
        }),
      ),
    ],
  );

  throwGroup.addCommand(ChatCommand(
    'die',
    'Throw a die',
    id('throw-die', (ChatContext context) {
      int number = Random().nextInt(6) + 1;

      context.respond(MessageBuilder(content: 'The die landed on the $number!'));
    }),
  ));

  commands.addCommand(throwGroup);

  ChatCommand say = ChatCommand(
    'say',
    'Make the bot say something',
    id('say', (ChatContext context, String message) {
      context.respond(MessageBuilder(content: message));
    }),
  );

  commands.addCommand(say);

  ChatCommand nick = ChatCommand(
    'nick',
    "Change a user's nickname",
    id('nick', (ChatContext context, Member target, String newNick) async {
      try {
        await target.update(MemberUpdateBuilder(nick: newNick));
      } on HttpResponseError {
        context.respond(MessageBuilder(content: "Couldn't change nickname :/"));
        return;
      }

      context.respond(MessageBuilder(content: 'Successfully changed nickname!'));
    }),
  );

  commands.addCommand(nick);

  Converter<Shape> shapeConverter = Converter<Shape>(
    (view, context) {
      switch (view.getQuotedWord().toLowerCase()) {
        case 'triangle':
          return Shape.triangle;
        case 'square':
          return Shape.square;
        case 'pentagon':
          return Shape.pentagon;
        default:
          return null;
      }
    },
    choices: [
      CommandOptionChoiceBuilder(name: 'Triangle', value: 'triangle'),
      CommandOptionChoiceBuilder(name: 'Square', value: 'square'),
      CommandOptionChoiceBuilder(name: 'Pentagon', value: 'pentagon'),
    ],
  );

  commands.addConverter(shapeConverter);

  Converter<Dimension> dimensionConverter = CombineConverter<int, Dimension>(
    intConverter,
    (number, context) {
      switch (number) {
        case 2:
          return Dimension.twoD;
        case 3:
          return Dimension.threeD;
        default:
          return null;
      }
    },
  );

  commands.addConverter(dimensionConverter);

  ChatCommand favoriteShape = ChatCommand(
    'favorite-shape',
    'Outputs your favorite shape',
    id('favorite-shape', (ChatContext context, Shape shape, Dimension dimension) {
      String favorite;

      switch (shape) {
        case Shape.triangle:
          if (dimension == Dimension.twoD) {
            favorite = 'triangle';
          } else {
            favorite = 'pyramid';
          }
          break;
        case Shape.square:
          if (dimension == Dimension.twoD) {
            favorite = 'square';
          } else {
            favorite = 'cube';
          }
          break;
        case Shape.pentagon:
          if (dimension == Dimension.twoD) {
            favorite = 'pentagon';
          } else {
            favorite = 'pentagonal prism';
          }
      }

      context.respond(MessageBuilder(content: 'Your favorite shape is $favorite!'));
    }),
  );

  commands.addCommand(favoriteShape);

  ChatCommand favoriteFruit = ChatCommand(
    'favorite-fruit',
    'Outputs your favorite fruit',
    id('favorite-fruit', (ChatContext context, [String favorite = 'apple']) {
      context.respond(MessageBuilder(content: 'Your favorite fruit is $favorite!'));
    }),
  );

  commands.addCommand(favoriteFruit);

  ChatCommand alphabet = ChatCommand(
    'alphabet',
    'Outputs the alphabet',
    id('alphabet', (ChatContext context) {
      context.respond(MessageBuilder(content: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'));
    }),
    checks: [
      CooldownCheck(
        CooldownType.user | CooldownType.guild,
        Duration(seconds: 30),
      )
    ],
  );

  commands.addCommand(alphabet);

  const Converter<String> nonEmptyStringConverter = CombineConverter(stringConverter, filterInput);

  ChatCommand betterSay = ChatCommand(
    'better-say',
    'A better version of the say command',
    id('better-say', (
      ChatContext context,
      @UseConverter(nonEmptyStringConverter) String input,
    ) {
      context.respond(MessageBuilder(content: input));
    }),
  );

  commands.addCommand(betterSay);
}

enum Shape {
  triangle,
  square,
  pentagon,
}

enum Dimension {
  twoD,
  threeD,
}

String? filterInput(String input, ContextData context) {
  if (input.isNotEmpty) {
    return input;
  }
  return null;
}
