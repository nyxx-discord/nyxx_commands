import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'member.dart';
import 'snowflake.dart';

Future<User?> snowflakeToUser(Snowflake snowflake, ContextData context) async {
  try {
    return await context.client.users.get(snowflake);
  } on HttpResponseError {
    return null;
  }
}

FutureOr<User?> memberToUser(Member member, ContextData context) => member.manager.client.users.get(member.id);

Future<User?> convertUser(StringView view, ContextData context) async {
  String word = view.getWord();
  TextChannel channel = context.channel;

  if (channel.type == ChannelType.dm || channel.type == ChannelType.groupDm) {
    List<User> exact = [];
    List<User> caseInsensitive = [];
    List<User> start = [];

    for (final user in [
      if (channel is DmChannel) channel.recipient,
      if (channel is GroupDmChannel) ...channel.recipients,
      await context.client.users.fetchCurrentUser(),
    ]) {
      if (user.username == word) {
        exact.add(user);
      }

      if (user.username.toLowerCase() == word.toLowerCase()) {
        caseInsensitive.add(user);
      }

      if (user.username.toLowerCase().startsWith(word.toLowerCase())) {
        start.add(user);
      }

      for (final list in [exact, caseInsensitive, start]) {
        if (list.length == 1) {
          return list.first;
        }
      }
    }
  }

  return null;
}

SelectMenuOptionBuilder userToSelectMenuOption(User user) => SelectMenuOptionBuilder(
      label: '@${user.username}',
      value: user.id.toString(),
    );

ButtonBuilder userToButton(User user) => ButtonBuilder(
      style: ButtonStyle.primary,
      label: '@${user.username}',
      customId: '',
    );

/// A converter that converts input to a [User].
///
/// This will first attempt to parse the input to a snowflake which will then be converted to a
/// [User]. If this fails, the input will be parsed as a [Member] which will then be converted to
/// a [User]. If this fails, the user will be looked up by name.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.user].
const Converter<User> userConverter = FallbackConverter<User>(
  [
    CombineConverter<Snowflake, User>(snowflakeConverter, snowflakeToUser),
    CombineConverter<Member, User>(memberConverter, memberToUser),
    Converter<User>(convertUser),
  ],
  type: CommandOptionType.user,
  toSelectMenuOption: userToSelectMenuOption,
  toButton: userToButton,
);
