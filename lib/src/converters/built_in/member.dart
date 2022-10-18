import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'snowflake.dart';

Future<IMember?> snowflakeToMember(Snowflake snowflake, IContextData context) async {
  if (context.guild != null) {
    IMember? cached = context.guild!.members[snowflake];
    if (cached != null) {
      return cached;
    }

    try {
      return await context.guild!.fetchMember(snowflake);
    } on IHttpResponseError {
      return null;
    }
  }
  return null;
}

Future<IMember?> convertMember(StringView view, IContextData context) async {
  String word = view.getQuotedWord();

  if (context.guild != null) {
    Stream<IMember> named = context.guild!.searchMembersGateway(word, limit: 800000);

    List<IMember> usernameExact = [];
    List<IMember> nickExact = [];

    List<IMember> usernameCaseInsensitive = [];
    List<IMember> nickCaseInsensitive = [];

    List<IMember> usernameStart = [];
    List<IMember> nickStart = [];

    await for (final member in named) {
      IUser user = await member.user.getOrDownload();

      if (user.username == word) {
        usernameExact.add(member);
      }
      if (user.username.toLowerCase() == word.toLowerCase()) {
        usernameCaseInsensitive.add(member);
      }
      if (user.username.toLowerCase().startsWith(word.toLowerCase())) {
        usernameStart.add(member);
      }

      if (member.nickname != null) {
        if (member.nickname! == word) {
          nickExact.add(member);
        }
        if (member.nickname!.toLowerCase() == word.toLowerCase()) {
          nickCaseInsensitive.add(member);
        }
        if (member.nickname!.toLowerCase().startsWith(word.toLowerCase())) {
          nickStart.add(member);
        }
      }
    }

    for (final list in [
      usernameExact,
      nickExact,
      usernameCaseInsensitive,
      nickCaseInsensitive,
      usernameStart,
      nickStart
    ]) {
      if (list.length == 1) {
        return list.first;
      }
    }
  }
  return null;
}

Future<MultiselectOptionBuilder> memberToMultiselectOption(IMember member) async {
  IUser user = await member.user.getOrDownload();
  String name = member.nickname ?? user.username;
  String discriminator = user.formattedDiscriminator;

  return MultiselectOptionBuilder(
    '$name#$discriminator',
    member.id.toString(),
  );
}

Future<ButtonBuilder> memberToButton(IMember member) async {
  IUser user = await member.user.getOrDownload();
  String name = member.nickname ?? user.username;
  String discriminator = user.formattedDiscriminator;

  return ButtonBuilder(
    '$name#$discriminator',
    '',
    ButtonStyle.primary,
  );
}

/// A converter that converts input to an [IMember].
///
/// This will first attempt to parse the input to a snowflake which will then be converted to an
/// [IMember]. If this fails, the member will be looked up by name.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.user].
const Converter<IMember> memberConverter = FallbackConverter<IMember>(
  [
    // Get member from mention or snowflake.
    CombineConverter<Snowflake, IMember>(snowflakeConverter, snowflakeToMember),
    // Get member by name or nickname
    Converter<IMember>(convertMember),
  ],
  type: CommandOptionType.user,
  toMultiselectOption: memberToMultiselectOption,
  toButton: memberToButton,
);
