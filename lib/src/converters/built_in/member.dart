import 'package:nyxx/nyxx.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'snowflake.dart';

Future<Member?> snowflakeToMember(Snowflake snowflake, ContextData context) async {
  try {
    return await context.guild?.members.get(snowflake);
  } on HttpResponseError {
    return null;
  }
}

Future<Member?> convertMember(StringView view, ContextData context) async {
  String word = view.getQuotedWord();

  if (context.guild == null) {
    return null;
  }

  List<Member> named = context.client is NyxxGateway
      ? await (context.client.gateway as Gateway)
          .listGuildMembers(context.guild!.id, query: word, limit: 100)
          .toList()
      : await context.guild!.members.search(word, limit: 100);

  List<Member> usernameExact = [];
  List<Member> nickExact = [];

  List<Member> usernameCaseInsensitive = [];
  List<Member> nickCaseInsensitive = [];

  List<Member> usernameStart = [];
  List<Member> nickStart = [];

  for (final member in named) {
    User user = await context.client.users.get(member.id);

    if (user.username == word) {
      usernameExact.add(member);
    }
    if (user.username.toLowerCase() == word.toLowerCase()) {
      usernameCaseInsensitive.add(member);
    }
    if (user.username.toLowerCase().startsWith(word.toLowerCase())) {
      usernameStart.add(member);
    }

    if (member.nick != null) {
      if (member.nick! == word) {
        nickExact.add(member);
      }
      if (member.nick!.toLowerCase() == word.toLowerCase()) {
        nickCaseInsensitive.add(member);
      }
      if (member.nick!.toLowerCase().startsWith(word.toLowerCase())) {
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
  return null;
}

Future<SelectMenuOptionBuilder> memberToSelectMenuOption(Member member) async {
  User user = await member.manager.client.users.get(member.id);
  String name = member.nick ?? user.globalName ?? user.username;

  return SelectMenuOptionBuilder(
    label: name,
    value: member.id.toString(),
    description: '@${user.username}',
  );
}

Future<ButtonBuilder> memberToButton(Member member) async {
  User user = await member.manager.client.users.get(member.id);
  String name = member.nick ?? user.globalName ?? user.username;

  return ButtonBuilder(
    style: ButtonStyle.primary,
    label: '$name (@${user.globalName})',
    customId: '',
  );
}

/// A converter that converts input to a [Member].
///
/// This will first attempt to parse the input to a snowflake which will then be converted to an
/// [Member]. If this fails, the member will be looked up by name.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.user].
const Converter<Member> memberConverter = FallbackConverter<Member>(
  [
    // Get member from mention or snowflake.
    CombineConverter<Snowflake, Member>(snowflakeConverter, snowflakeToMember),
    // Get member by name or nickname
    Converter<Member>(convertMember),
  ],
  type: CommandOptionType.user,
  toSelectMenuOption: memberToSelectMenuOption,
  toButton: memberToButton,
);
