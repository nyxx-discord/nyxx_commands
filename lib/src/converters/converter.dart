//  Copyright 2021 Abitofevrything and others.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/context/chat_context.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:nyxx_commands/src/util/view.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// Object used to convert raw argument strings to the type required by the
/// command using them.
class Converter<T> {
  /// The function called to process the input.
  ///
  /// If this function returns null, a [BadInputException] is thrown.
  ///
  /// The first [StringView] parameter should be left with its index pointing to the position from
  /// which the next argument should be parsed.
  final FutureOr<T?> Function(StringView view, IChatContext context) convert;

  /// A Iterable of choices users can choose from.
  ///
  /// There is a maximum of 25 choices per option.
  final Iterable<ArgChoiceBuilder>? choices;

  /// The [CommandOptionType] that arguments using this converter will use for Discord slash
  /// commands.
  final CommandOptionType type;

  /// The output [Type] of this converter.
  final Type output;

  /// Construct a new [Converter].
  ///
  /// This must then be registered to a [CommandsPlugin] instance with
  /// [CommandsPlugin.addConverter].
  const Converter(
    this.convert, {
    this.choices,
    this.type = CommandOptionType.string,
  }) : output = T;

  @override
  String toString() => 'Converter<$T>';
}

/// Object used to combine converters.
///
/// This is useful in cases where a preliminary parsing can then be refined by applying a filter
/// to the output, especially if the preliminary parsing can be done on Discord in the case of slash
/// commands.
class CombineConverter<R, T> implements Converter<T> {
  /// The initial [Converter].
  ///
  /// The output of this converter will be fed into [process] along with the context.
  final Converter<R> converter;

  /// The function used to further process the output of [converter].
  final FutureOr<T?> Function(R, IChatContext) process;

  /// The output [Type] of this converter.
  @override
  final Type output;

  final Iterable<ArgChoiceBuilder>? _choices;
  final CommandOptionType? _type;

  /// Construct a new [CombineConverter].
  ///
  /// This must then be registered to a [CommandsPlugin] instance with
  /// [CommandsPlugin.addConverter].
  ///
  /// The choices for this converter will be inherited from [converter], but can be overridden by
  /// passing [choices].
  ///
  /// The type for this converter will be inherited from [converter], but can be overridden by
  /// passing [type].
  const CombineConverter(
    this.converter,
    this.process, {
    Iterable<ArgChoiceBuilder>? choices,
    CommandOptionType? type,
  })  : _choices = choices,
        _type = type,
        output = T;

  @override
  Iterable<ArgChoiceBuilder>? get choices => _choices ?? converter.choices;

  @override
  CommandOptionType get type => _type ?? converter.type;

  @override
  FutureOr<T?> Function(StringView view, IChatContext context) get convert =>
      (view, context) async {
        R? ret = await converter.convert(view, context);

        if (ret != null) {
          return await process(ret, context);
        }
        return null;
      };

  @override
  String toString() => 'CombineConverter<$R, $T>[converter=$converter]';
}

/// Object used to successivly try similar [Converter]s until a successful parsing is found.
class FallbackConverter<T> implements Converter<T> {
  /// A list of [Converter]s this [FallbackConverter] will try in succession.
  final Iterable<Converter<T>> converters;

  final Iterable<ArgChoiceBuilder>? _choices;
  final CommandOptionType? _type;

  /// The output [Type] of this converter.
  @override
  final Type output;

  /// Construct a new [FallbackConverter].
  ///
  /// This must then be registered to a [CommandsPlugin] instance with
  /// [CommandsPlugin.addConverter].
  ///
  /// The choices for this converter will be inherited from [converters], but can be overridden by
  /// passing [choices].
  ///
  /// The type for this converter will be inferred from [converters], but can be overridden by
  /// passing [type].
  const FallbackConverter(
    this.converters, {
    Iterable<ArgChoiceBuilder>? choices,
    CommandOptionType? type,
  })  : _choices = choices,
        _type = type,
        output = T;

  @override
  Iterable<ArgChoiceBuilder>? get choices {
    if (_choices != null) {
      return _choices;
    }

    List<ArgChoiceBuilder> allChoices = [];

    for (final converter in converters) {
      Iterable<ArgChoiceBuilder>? converterChoices = converter.choices;

      if (converterChoices == null) {
        return null;
      }

      for (final choice in converterChoices) {
        ArgChoiceBuilder existing =
            allChoices.singleWhere((element) => element.name == choice.name, orElse: () => choice);

        if (existing.value != choice.value) {
          return null;
        } else if (identical(choice, existing)) {
          allChoices.add(choice);
        }
      }
    }

    if (allChoices.isEmpty || allChoices.length > 25) {
      return null;
    }

    return allChoices;
  }

  @override
  CommandOptionType get type {
    if (_type != null) {
      return _type!;
    }

    Iterable<CommandOptionType> converterTypes = converters.map((converter) => converter.type);

    if (converterTypes.every((element) => element == converterTypes.first)) {
      return converterTypes.first;
    }

    return CommandOptionType.string;
  }

  @override
  FutureOr<T?> Function(StringView view, IChatContext context) get convert =>
      (view, context) async {
        StringView? used;
        T? ret = await converters.fold(Future.value(null), (previousValue, element) async {
          if (await previousValue != null) {
            return await previousValue;
          }

          used = view.copy();
          return await element.convert(used!, context);
        });

        if (used != null) {
          view.history
            ..clear()
            ..addAll(used!.history);

          view.index = used!.index;
        }

        return ret;
      };

  @override
  String toString() => 'FallbackConverter<$T>[converters=${List.of(converters)}]';
}

String? convertString(StringView view, IChatContext context) => view.getQuotedWord();

/// Converter to convert input to [String]s.
///
/// This simply returns the next quoted word in the arguments view.
const Converter<String> stringConverter = Converter<String>(
  convertString,
  type: CommandOptionType.string,
);

int? convertInt(StringView view, IChatContext context) => int.tryParse(view.getQuotedWord());

/// Converter to convert input to [int]s.
///
/// This attempts to parse the next quoted word in the input as a base-10 integer.
const Converter<int> intConverter = Converter<int>(
  convertInt,
  type: CommandOptionType.integer,
);

double? convertDouble(StringView view, IChatContext context) =>
    double.tryParse(view.getQuotedWord());

/// Converter to convert input to [double]s.
///
/// This attempts to parse the next quoted word in the input as a base-10 decimal number.
const Converter<double> doubleConverter = Converter<double>(
  convertDouble,
  type: CommandOptionType.number,
);

bool? convertBool(StringView view, IChatContext context) {
  String word = view.getQuotedWord();

  const Iterable<String> truthy = ['y', 'yes', '+', '1', 'true'];
  const Iterable<String> falsy = ['n', 'no', '-', '0', 'false'];

  const Iterable<String> valid = [...truthy, ...falsy];

  if (valid.contains(word.toLowerCase())) {
    return truthy.contains(word.toLowerCase());
  }

  return null;
}

/// Converter to convert input to [bool]s.
///
/// This checks two lists of truthy/falsy values, listed below:
/// - Truthy: `['y', 'yes', '+', '1', 'true']`
/// - Falsy: `['n', 'no', '-', '0', 'false']`
///
/// This converter is case insensitive.
const Converter<bool> boolConverter = Converter<bool>(
  convertBool,
  type: CommandOptionType.boolean,
);

final RegExp _snowflakePattern = RegExp(r'^(?:<(?:@(?:!|&)?|#)([0-9]{15,20})>|([0-9]{15,20}))$');

Snowflake? convertSnowflake(StringView view, IChatContext context) {
  String word = view.getQuotedWord();
  if (!_snowflakePattern.hasMatch(word)) {
    return null;
  }

  final RegExpMatch match = _snowflakePattern.firstMatch(word)!;

  // 1st group will catch mentions, second will catch raw IDs
  return Snowflake(match.group(1) ?? match.group(2));
}

/// Converter to convert input to [Snowflake]s.
///
/// This tries to parse the next word in the input as a raw snowflake (integer), or as a mention.
const Converter<Snowflake> snowflakeConverter = Converter<Snowflake>(
  convertSnowflake,
);

Future<IMember?> snowflakeToMember(Snowflake snowflake, IChatContext context) async {
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

Future<IMember?> convertMember(StringView view, IChatContext context) async {
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

/// Converter to convert input to [IMember]s.
///
/// This uses multiple strategies to look up members, in the order below:
/// - ID lookup (parse input as snowflake or mention)
/// - Exact username match
/// - Exact nickname match
/// - Full case insensitive username match
/// - Full case insensitive nickname match
/// - Partial case insensitive username match (username starts with input)
/// - Partial case insensitive nickname match (nickname starts with input)
///
/// Note that for all of these strategies, if multiple members match any condition then no results
/// will be given based off of that condition.
const Converter<IMember> memberConverter = FallbackConverter<IMember>(
  [
    // Get member from mention or snowflake.
    CombineConverter<Snowflake, IMember>(snowflakeConverter, snowflakeToMember),
    // Get member by name or nickname
    Converter<IMember>(convertMember),
  ],
  type: CommandOptionType.user,
);

Future<IUser?> snowflakeToUser(Snowflake snowflake, IChatContext context) async {
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

FutureOr<IUser?> memberToUser(IMember member, IChatContext context) => member.user.getOrDownload();

FutureOr<IUser?> convertUser(StringView view, IChatContext context) {
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

/// Converter to convert input to [IUser]s.
///
/// This uses multiple strategies to look up users, in the order below:
/// - ID lookup (parse input as snowflake)
/// - Member lookup (convert to member using [memberConverter] and extract [IMember.user])
/// - Exact username match
/// - Full case insensitive username match
/// - Partial case insensitive username match (username starts with input)
///
/// Note that for all of these strategies, if multiple users match any condition then no results
/// will be given based off of that condition.
const Converter<IUser> userConverter = FallbackConverter<IUser>(
  [
    CombineConverter<Snowflake, IUser>(snowflakeConverter, snowflakeToUser),
    CombineConverter<IMember, IUser>(memberConverter, memberToUser),
    Converter<IUser>(convertUser),
  ],
  type: CommandOptionType.user,
);

T? snowflakeToGuildChannel<T extends IGuildChannel>(Snowflake snowflake, IChatContext context) {
  if (context.guild == null) {
    return null;
  }

  try {
    return context.guild!.channels.whereType<T>().firstWhere((channel) => channel.id == snowflake);
  } on StateError {
    return null;
  }

  return null;
}

T? convertGuildChannel<T extends IGuildChannel>(StringView view, IChatContext context) {
  if (context.guild == null) {
    return null;
  }

  String word = view.getQuotedWord();
  Iterable<T> channels = context.guild!.channels.whereType<T>();

  List<T> caseInsensitive = [];
  List<T> partial = [];

  for (final channel in channels) {
    if (channel.name.toLowerCase() == word.toLowerCase()) {
      caseInsensitive.add(channel);
    }
    if (channel.name.toLowerCase().startsWith(word.toLowerCase())) {
      partial.add(channel);
    }
  }

  for (final list in [caseInsensitive, partial]) {
    if (list.length == 1) {
      return list.first;
    }
  }

  return null;
}

/// Converter to convert input to [IGuildChannel]s.
///
/// This uses multiple strategies to look up channels, in the order below:
/// - ID lookup (parse input as snowflake)
/// - Full case insensitive channel name match
/// - Partial case insensitive channel name match (channel name starts with
/// input)
///
/// Note that for all of these strategies, if multiple channels match any condition then no results
/// will be given based off of that condition.
const Converter<IGuildChannel> guildChannelConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, IGuildChannel>(
        snowflakeConverter, snowflakeToGuildChannel<IGuildChannel>),
    Converter<IGuildChannel>(convertGuildChannel<IGuildChannel>),
  ],
  type: CommandOptionType.channel,
);

/// Converter to convert input to [ITextGuildChannel]s.
///
/// This uses multiple strategies to look up channels, in the order below:
/// - ID lookup (parse input as snowflake)
/// - Full case insensitive channel name match
/// - Partial case insensitive channel name match (channel name starts with
/// input)
///
/// Note that for all of these strategies, if multiple channels match any condition then no results
/// will be given based off of that condition.
const Converter<ITextGuildChannel> textGuildChannelConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, ITextGuildChannel>(
        snowflakeConverter, snowflakeToGuildChannel<ITextGuildChannel>),
    Converter<ITextGuildChannel>(convertGuildChannel<ITextGuildChannel>),
  ],
  type: CommandOptionType.channel,
);

/// Converter to convert input to [IVoiceGuildChannel]s.
///
/// This uses multiple strategies to look up channels, in the order below:
/// - ID lookup (parse input as snowflake)
/// - Full case insensitive channel name match
/// - Partial case insensitive channel name match (channel name starts with
/// input)
///
/// Note that for all of these strategies, if multiple channels match any condition then no results
/// will be given based off of that condition.
const Converter<IVoiceGuildChannel> voiceGuildChannelConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, IVoiceGuildChannel>(
        snowflakeConverter, snowflakeToGuildChannel<IVoiceGuildChannel>),
    Converter<IVoiceGuildChannel>(convertGuildChannel<IVoiceGuildChannel>),
  ],
  type: CommandOptionType.channel,
);

/// Converter to convert input to [ICategoryGuildChannel]s.
///
/// This uses multiple strategies to look up channels, in the order below:
/// - ID lookup (parse input as snowflake)
/// - Full case insensitive channel name match
/// - Partial case insensitive channel name match (channel name starts with
/// input)
///
/// Note that for all of these strategies, if multiple channels match any condition then no results
/// will be given based off of that condition.
const Converter<ICategoryGuildChannel> categoryGuildChannelConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, ICategoryGuildChannel>(
        snowflakeConverter, snowflakeToGuildChannel<ICategoryGuildChannel>),
    Converter<ICategoryGuildChannel>(convertGuildChannel<ICategoryGuildChannel>),
  ],
  type: CommandOptionType.channel,
);

/// Converter to convert input to [IStageVoiceGuildChannel]s.
///
/// This uses multiple strategies to look up channels, in the order below:
/// - ID lookup (parse input as snowflake)
/// - Full case insensitive channel name match
/// - Partial case insensitive channel name match (channel name starts with
/// input)
///
/// Note that for all of these strategies, if multiple channels match any condition then no results
/// will be given based off of that condition.
const Converter<IStageVoiceGuildChannel> stageVoiceChannelConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, IStageVoiceGuildChannel>(
        snowflakeConverter, snowflakeToGuildChannel<IStageVoiceGuildChannel>),
    Converter<IStageVoiceGuildChannel>(convertGuildChannel<IStageVoiceGuildChannel>),
  ],
  type: CommandOptionType.channel,
);

FutureOr<IRole?> snowflakeToRole(Snowflake snowflake, IChatContext context) {
  if (context.guild == null) {
    return null;
  }

  IRole? cached = context.guild!.roles[snowflake];
  if (cached != null) {
    return cached;
  }

  try {
    return context.guild!.fetchRoles().firstWhere((role) => role.id == snowflake);
  } on StateError {
    return null;
  }

  return null;
}

FutureOr<IRole?> convertRole(StringView view, IChatContext context) async {
  String word = view.getQuotedWord();
  if (context.guild != null) {
    Stream<IRole> roles = context.guild!.fetchRoles();

    List<IRole> exact = [];
    List<IRole> caseInsensitive = [];
    List<IRole> partial = [];

    await for (final role in roles) {
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

/// Converter to convert input to [IRole]s.
///
/// This uses multiple strategies to look up roles, in the order below:
/// - ID lookup (parse input as snowflake)
/// - Exact role name match
/// - Full case insensitive role name match
/// - Partial case insensitive role name match (role name starts with
/// input)
///
/// Note that for all of these strategies, if multiple channels match any condition then no results
/// will be given based off of that condition.
const Converter<IRole> roleConverter = FallbackConverter<IRole>(
  [
    CombineConverter<Snowflake, IRole>(snowflakeConverter, snowflakeToRole),
    Converter<IRole>(convertRole),
  ],
  type: CommandOptionType.role,
);

/// Converter to convert input to [Mentionable]s.
///
/// This uses multiple strategiiees to look up mentionables, in the order below:
/// - Member lookup, see [memberConverter] for details
/// - Role lookup, see [roleConverter] for details.
const Converter<Mentionable> mentionableConverter = FallbackConverter(
  [
    memberConverter,
    roleConverter,
  ],
  type: CommandOptionType.mentionable,
);

/// Attempt to parse a single argument from an argument view.
///
/// [commands] is the [CommandsPlugin] used for retrieving the converters for a specific [Type]. If
/// no converter for [expectedType] is found, a [NoConverterException] is thrown.
Future<dynamic> parse(
  CommandsPlugin commands,
  IChatContext context,
  StringView toParse,
  Type expectedType, {
  Converter<dynamic>? converterOverride,
}) async {
  Converter<dynamic>? converter = converterOverride ?? commands.getConverter(expectedType);
  if (converter == null) {
    throw NoConverterException(expectedType, context);
  }

  try {
    dynamic parsed = await converter.convert(toParse, context);

    if (parsed == null) {
      throw BadInputException('Could not parse input $context to type "$expectedType"', context);
    }

    return parsed;
  } on ParsingException catch (e) {
    throw BadInputException('Bad input $context: ${e.message}', context);
  }
}

/// Register default converters for a [CommandsPlugin].
///
/// This registers converters for commonly used types such as [String]s, [int]s or [double]s.
void registerDefaultConverters(CommandsPlugin commands) {
  commands
    ..addConverter(stringConverter)
    ..addConverter(intConverter)
    ..addConverter(doubleConverter)
    ..addConverter(boolConverter)
    ..addConverter(snowflakeConverter)
    ..addConverter(memberConverter)
    ..addConverter(userConverter)
    ..addConverter(guildChannelConverter)
    ..addConverter(textGuildChannelConverter)
    ..addConverter(voiceGuildChannelConverter)
    ..addConverter(stageVoiceChannelConverter)
    ..addConverter(roleConverter)
    ..addConverter(mentionableConverter);
}
