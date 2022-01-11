// This is a file containing a "clean" version of example.dart, with comments stripped for
// readability.
// This file is generated automatically by scripts/generate_clean_example and should not be edited
// manually; edit example.dart and run scripts/generate_clean_example.

import 'package:nyxx/nyxx.dart';

import 'package:nyxx_commands/nyxx_commands.dart';

import 'dart:io';
import 'dart:math';

import 'package:nyxx_interactions/nyxx_interactions.dart';

void main() {
  INyxxWebsocket client = NyxxFactory.createNyxxWebsocket(
    Platform.environment['TOKEN']!,
    GatewayIntents.allUnprivileged | GatewayIntents.guildMembers,
  );

  CommandsPlugin commands = CommandsPlugin(
    prefix: (message) => '!',
    guild: Snowflake(Platform.environment['GUILD']!),
    options: CommandsOptions(
      logErrors: true,
    ),
  );

  client.registerPlugin(commands);

  client
    ..registerPlugin(Logging())
    ..registerPlugin(CliIntegration())
    ..registerPlugin(IgnoreExceptions());

  client.connect();

  Command ping = Command(
    'ping',
    'Checks if the bot is online',
    (Context context) {
      context.respond(MessageBuilder.content('pong!'));
    },
  );

  commands.addCommand(ping);

  Group throwGroup = Group(
    'throw',
    'Throw an objet',
    children: [
      Command(
        'coin',
        'Throw a coin',
        (Context context) {
          bool heads = Random().nextBool();

          context.respond(
              MessageBuilder.content('The coin landed on its ${heads ? 'head' : 'tail'}!'));
        },
      ),
    ],
  );

  throwGroup.addCommand(Command(
    'die',
    'Throw a die',
    (Context context) {
      int number = Random().nextInt(6) + 1;

      context.respond(MessageBuilder.content('The die landed on the $number!'));
    },
  ));

  commands.addCommand(throwGroup);

  Command say = Command(
    'say',
    'Make the bot say something',
    (Context context, String message) {
      context.respond(MessageBuilder.content(message));
    },
  );

  commands.addCommand(say);

  Command nick = Command(
    'nick',
    "Change a user's nickname",
    (Context context, IMember target, String newNick) async {
      try {
        await target.edit(nick: newNick);
      } on IHttpResponseError {
        context.respond(MessageBuilder.content("Couldn't change nickname :/"));
        return;
      }

      context.respond(MessageBuilder.content('Successfully changed nickname!'));
    },
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
      ArgChoiceBuilder('Triangle', 'triangle'),
      ArgChoiceBuilder('Square', 'square'),
      ArgChoiceBuilder('Pentagon', 'pentagon'),
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

  Command favouriteShape = Command(
    'favourite-shape',
    'Outputs your favourite shape',
    (Context context, Shape shape, Dimension dimension) {
      String favourite;

      switch (shape) {
        case Shape.triangle:
          if (dimension == Dimension.twoD) {
            favourite = 'triangle';
          } else {
            favourite = 'pyramid';
          }
          break;
        case Shape.square:
          if (dimension == Dimension.twoD) {
            favourite = 'square';
          } else {
            favourite = 'cube';
          }
          break;
        case Shape.pentagon:
          if (dimension == Dimension.twoD) {
            favourite = 'pentagon';
          } else {
            favourite = 'pentagonal prism';
          }
      }

      context.respond(MessageBuilder.content('Your favourite shape is $favourite!'));
    },
  );

  commands.addCommand(favouriteShape);

  Command favouriteFruit = Command(
    'favourite-fruit',
    'Outputs your favourite fruit',
    (Context context, [String favourite = 'apple']) {
      context.respond(MessageBuilder.content('Your favourite fruit is $favourite!'));
    },
  );

  commands.addCommand(favouriteFruit);

  Command alphabet = Command(
    'alphabet',
    'Outputs the alphabet',
    (Context context) {
      context.respond(MessageBuilder.content('ABCDEFGHIJKLMNOPQRSTUVWXYZ'));
    },
    checks: [
      CooldownCheck(
        CooldownType.user,
        Duration(seconds: 30),
      )
    ],
  );

  commands.addCommand(alphabet);

  const Converter<String> nonEmptyStringConverter = CombineConverter(stringConverter, filterInput);

  Command betterSay = Command(
    'better-say',
    'A better version of the say command',
    (
      Context context,
      @UseConverter(nonEmptyStringConverter) String input,
    ) {
      context.respond(MessageBuilder.content(input));
    },
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

String? filterInput(String input, Context context) {
  if (input.isNotEmpty) {
    return input;
  }
  return null;
}
