import 'package:nyxx/nyxx.dart';

import '../converter.dart';
import '../fallback.dart';
import 'user.dart';
import 'role.dart';

/// A converter that converts input to a [Mentionable].
///
/// This will first attempt to convert the input as a member, then as a role.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.mentionable].
const Converter<CommandOptionMentionable> mentionableConverter = FallbackConverter(
  [
    userConverter,
    roleConverter,
  ],
  type: CommandOptionType.mentionable,
);
