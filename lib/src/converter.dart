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
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'commands.dart';
import 'context.dart';
import 'errors.dart';
import 'view.dart';

/// Mapping of Dart [Type]s to their Discord API equivalents.
///
/// Adding new types to this map will cause slash commands to use the specified [CommandOptionType]
/// when that type is needed. The result can then be processed again on the bot, unless the type
/// returned by the API is already assignable to the required argument type.
final Map<Type, CommandOptionType> discordTypes = {
  // Basic types
  bool: CommandOptionType.boolean,
  int: CommandOptionType.integer,
  String: CommandOptionType.string,

  // User types
  IMember: CommandOptionType.user,
  IUser: CommandOptionType.user,

  // Channel types
  IGuildChannel: CommandOptionType.channel,
  ITextGuildChannel: CommandOptionType.channel,
  ICategoryGuildChannel: CommandOptionType.channel,
  IVoiceGuildChannel: CommandOptionType.channel,
  IStageVoiceGuildChannel: CommandOptionType.channel,

  // Role types
  IRole: CommandOptionType.role,
};

/// Object used to convert raw argument strings to the type required by the
/// command using them.
class Converter<T> {
  /// The function called to process the input.
  ///
  /// If this function returns null, a [BadInputException] is thrown.
  ///
  /// The first [StringView] parameter should be left with its index pointing to the position from
  /// which the next argument should be parsed.
  final FutureOr<T?> Function(StringView, Context) convert;

  /// A Iterable of choices users can choose from.
  ///
  /// There is a maximum of 25 choices per option.
  final Iterable<ArgChoiceBuilder>? choices;

  /// Construct a new [Converter].
  ///
  /// This must then be registered to a [CommandsPlugin] instance with [CommandsPlugin.addConverter].
  Converter(this.convert, {this.choices});

  @override
  String toString() => 'Converter<$T>';
}

/// Object used to combine converters.
///
/// This is useful in cases where a preliminary parsing can then be refined by applying a filter
/// to the output, especially if the preliminary parsing can be done on Discord in the case of slash
/// commands.
class CombineConverter<R, T> extends Converter<T> {
  /// The initial [Converter].
  ///
  /// The output of this converter will be fed into [process] along with the context.
  final Converter<R> converter;

  /// The function used to further process the output of [converter].
  final FutureOr<T?> Function(R, Context) process;

  /// Construct a new [CombineConverter].
  ///
  /// This must then be registered to a [CommandsPlugin] instance with [CommandsPlugin.addConverter].
  CombineConverter(this.converter, this.process)
      : super((view, context) async {
          R? ret = await converter.convert(view, context);

          if (ret != null) {
            return await process(ret, context);
          }
          return null;
        });

  @override
  Iterable<ArgChoiceBuilder>? get choices => converter.choices;

  @override
  String toString() => 'CombineConverter<$R, $T>[converter=$converter]';
}

/// Object used to successivly try similar [Converter]s until a successful parsing is found.
class FallbackConverter<T> extends Converter<T> {
  /// A list of [Converter]s this [FallbackConverter] will try in succession.
  final Iterable<Converter<T>> converters;

  /// Construct a new [FallbackConverter].
  ///
  /// This must then be registered to a [CommandsPlugin] instance with [CommandsPlugin.addConverter].
  FallbackConverter(this.converters)
      : super((view, context) async {
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
        });

  @override
  Iterable<ArgChoiceBuilder>? get choices {
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
  String toString() => 'FallbackConverter<$T>[converters=${List.of(converters)}]';
}

/// Converter to convert input to [String]s.
///
/// This simply returns the next quoted word in the arguments view.
final Converter<String> stringConverter = Converter<String>(
  (input, _) => input.getQuotedWord(),
);

/// Converter to convert input to [int]s.
///
/// This attempts to parse the next quoted word in the input as a base-10 integer.
final Converter<int> intConverter = Converter<int>(
  (input, _) => int.tryParse(input.getQuotedWord()),
);

/// Converter to convert input to [double]s.
///
/// This attempts to parse the next quoted word in the input as a base-10 decimal number.
final Converter<double> doubleConverter = Converter<double>(
  (input, _) => double.tryParse(input.getQuotedWord()),
);

/// Converter to convert input to [bool]s.
///
/// This checks two lists of truthy/falsy values, listed below:
/// - Tuthy: `['y', 'yes', '+', '1', 'true']`
/// - Falsy: `['n', 'no', '-', '0', 'false']`
///
/// This converter is case insensitive.
final Converter<bool> boolConverter = Converter<bool>((view, context) {
  String word = view.getQuotedWord();

  const Iterable<String> truthy = ['y', 'yes', '+', '1', 'true'];
  const Iterable<String> falsy = ['n', 'no', '-', '0', 'false'];

  const Iterable<String> valid = [...truthy, ...falsy];

  if (valid.contains(word.toLowerCase())) {
    return truthy.contains(word.toLowerCase());
  }

  return null;
});

final RegExp _snowflakePattern = RegExp(r'^(?:<(?:@(?:!|&)?|#)([0-9]{15,20})>|([0-9]{15,20}))$');

/// Converter to convert input to [Snowflake]s.
///
/// This tries to parse the next word in the input as a raw snowflake (integer), or as a mention.
final Converter<Snowflake> snowflakeConverter = Converter<Snowflake>(
  (input, _) {
    String word = input.getQuotedWord();
    if (!_snowflakePattern.hasMatch(word)) {
      return null;
    }

    final RegExpMatch match = _snowflakePattern.firstMatch(word)!;

    // 1st group will catch mentions, second will catch raw IDs
    return Snowflake(match.group(1) ?? match.group(2));
  },
);

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
final Converter<IMember> memberConverter = FallbackConverter<IMember>([
  // Get member from mention or snowflake.
  CombineConverter<Snowflake, IMember>(snowflakeConverter, (snowflake, context) async {
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
  }),
  // Get member by name or nickname
  Converter<IMember>((view, context) async {
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
  }),
]);

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
final Converter<IUser> userConverter = FallbackConverter<IUser>([
  CombineConverter<Snowflake, IUser>(snowflakeConverter, (snowflake, context) async {
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
  }),
  CombineConverter<IMember, IUser>(
      memberConverter, (member, context) => member.user.getOrDownload()),
  Converter<IUser>((view, context) {
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
  }),
]);

Converter<T> _guildChannelConverterFor<T extends IGuildChannel>() {
  return FallbackConverter<T>([
    CombineConverter<Snowflake, T>(snowflakeConverter, (snowflake, context) async {
      if (context.guild != null) {
        try {
          return context.guild!.channels
              .whereType<T>()
              .firstWhere((channel) => channel.id == snowflake);
        } on StateError {
          return null;
        }
      }
    }),
    Converter<T>((view, context) {
      if (context.guild != null) {
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
      }
    }),
  ]);
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
final Converter<IGuildChannel> guildChannelConverter = _guildChannelConverterFor<IGuildChannel>();

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
final Converter<ITextGuildChannel> textGuildChannelConverter =
    _guildChannelConverterFor<ITextGuildChannel>();

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
final Converter<IVoiceGuildChannel> voiceGuildChannelConverter =
    _guildChannelConverterFor<IVoiceGuildChannel>();

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
final Converter<ICategoryGuildChannel> categoryGuildChannelConverter =
    _guildChannelConverterFor<ICategoryGuildChannel>();

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
final Converter<IStageVoiceGuildChannel> stageVoiceChannelConverter =
    _guildChannelConverterFor<IStageVoiceGuildChannel>();

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
final Converter<IRole> roleConverter = FallbackConverter<IRole>([
  CombineConverter<Snowflake, IRole>(snowflakeConverter, (snowflake, context) {
    if (context.guild != null) {
      IRole? cached = context.guild!.roles[snowflake];
      if (cached != null) {
        return cached;
      }

      try {
        return context.guild!.fetchRoles().firstWhere((role) => role.id == snowflake);
      } on StateError {
        return null;
      }
    }
  }),
  Converter<IRole>((view, context) async {
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
  }),
]);

/// Attempt to parse a single argument from an argument view.
///
/// [commands] is the [CommandsPlugin] used for retrieving the converters for a specific [Type]. If no converter
/// for [expectedType] is found, a [NoConverterException] is thrown.
Future<dynamic> parse(
    CommandsPlugin commands, Context context, StringView toParse, Type expectedType) async {
  Converter<dynamic>? converter = commands.converterFor(expectedType);
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
    ..addConverter(roleConverter);
}
