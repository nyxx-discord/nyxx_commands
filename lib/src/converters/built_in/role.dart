import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'snowflake.dart';

Future<Role?> snowflakeToRole(Snowflake snowflake, ContextData context) async {
  try {
    return await context.guild?.roles.get(snowflake);
  } on RoleNotFoundException {
    return null;
  }
}

Future<Role?> convertRole(StringView view, ContextData context) async {
  String word = view.getQuotedWord();

  if (context.guild != null) {
    List<Role> roles = await context.guild!.roles.list();

    List<Role> exact = [];
    List<Role> caseInsensitive = [];
    List<Role> partial = [];

    for (final role in roles) {
      if (role.name == word) {
        exact.add(role);
      }
      if (role.name.toLowerCase() == word.toLowerCase()) {
        caseInsensitive.add(role);
      }
      if (role.name.toLowerCase().startsWith(word.toLowerCase())) {
        partial.add(role);
      }
    }

    for (final list in [exact, caseInsensitive, partial]) {
      if (list.length == 1) {
        return list.first;
      }
    }
  }
  return null;
}

SelectMenuOptionBuilder roleToSelectMenuOption(Role role) {
  SelectMenuOptionBuilder builder = SelectMenuOptionBuilder(
    label: role.name,
    value: role.id.toString(),
  );

  if (role.unicodeEmoji != null) {
    builder.emoji = TextEmoji(
      id: Snowflake.zero,
      manager: role.manager.client.guilds[Snowflake.zero].emojis,
      name: role.unicodeEmoji!,
    );
  }

  return builder;
}

ButtonBuilder roleToButton(Role role) {
  final builder = ButtonBuilder(
    style: ButtonStyle.primary,
    label: role.name,
    customId: '',
  );

  if (role.unicodeEmoji != null) {
    builder.emoji = TextEmoji(
      id: Snowflake.zero,
      manager: role.manager.client.guilds[Snowflake.zero].emojis,
      name: role.unicodeEmoji!,
    );
  }

  return builder;
}

/// A converter that converts input to a [Role].
///
/// This will first attempt to parse the input as a snowflake that will then be converted to a
/// [Role]. If this fails, then the role will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.role].
const Converter<Role> roleConverter = FallbackConverter<Role>(
  [
    CombineConverter<Snowflake, Role>(snowflakeConverter, snowflakeToRole),
    Converter<Role>(convertRole),
  ],
  type: CommandOptionType.role,
  toSelectMenuOption: roleToSelectMenuOption,
  toButton: roleToButton,
);
