import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'member.dart';
import 'snowflake.dart';

Future<IUser?> snowflakeToUser(Snowflake snowflake, IContextData context) async {
  IUser? cached = context.client.users[snowflake];
  if (cached != null) {
    return cached;
  }

  if (context.client is INyxxRest) {
    try {
      return await (context.client as INyxxRest).httpEndpoints.fetchUser(snowflake);
    } on IHttpResponseError {
      return null;
    }
  }

  return null;
}

FutureOr<IUser?> memberToUser(IMember member, IContextData context) => member.user.getOrDownload();

FutureOr<IUser?> convertUser(StringView view, IContextData context) {
  String word = view.getWord();

  if (context.channel.channelType == ChannelType.dm ||
      context.channel.channelType == ChannelType.groupDm) {
    List<IUser> exact = [];
    List<IUser> caseInsensitive = [];
    List<IUser> start = [];

    for (final user in [
      ...(context.channel as IDMChannel).participants,
      if (context.client is INyxxRest) (context.client as INyxxRest).self,
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

MultiselectOptionBuilder userToMultiselectOption(IUser user) => MultiselectOptionBuilder(
      '${user.username}#${user.formattedDiscriminator}',
      user.id.toString(),
    );

ButtonBuilder userToButton(IUser user) => ButtonBuilder(
      '${user.username}#${user.formattedDiscriminator}',
      '',
      ButtonStyle.primary,
    );

/// A converter that converts input to an [IUser].
///
/// This will first attempt to parse the input to a snowflake which will then be converted to an
/// [IUser]. If this fails, the input will be parsed as an [IMember] which will then be converted to
/// an [IUser]. If this fails, the user will be looked up by name.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.user].
const Converter<IUser> userConverter = FallbackConverter<IUser>(
  [
    CombineConverter<Snowflake, IUser>(snowflakeConverter, snowflakeToUser),
    CombineConverter<IMember, IUser>(memberConverter, memberToUser),
    Converter<IUser>(convertUser),
  ],
  type: CommandOptionType.user,
  toMultiselectOption: userToMultiselectOption,
  toButton: userToButton,
);
