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
import 'package:nyxx_commands/src/context/base.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands.dart';
import '../context/autocomplete_context.dart';
import '../context/chat_context.dart';
import '../errors.dart';
import '../util/view.dart';

/// Contains metadata and parsing capabilities for a given type.
///
/// A [Converter] will convert textual user input received from the Discord API to the type
/// requested by the current command. It also contains metadata about the type it converts.
///
/// nyxx_commands provides a set of converters for common argument types, a list of which can be
/// found below. These converters are automatically added to [CommandsPlugin] instances and do not
/// need to be added manually.
///
/// The list of default converters is as follows:
/// - [stringConverter], which converts [String]s;
/// - [intConverter], which converts [int]s;
/// - [doubleConverter], which converts [double]s;
/// - [boolConverter], which converts [bool]s;
/// - [snowflakeConverter], which converts [Snowflake]s;
/// - [memberConverter], which converts [IMember]s;
/// - [userConverter], which converts [IUser]s;
/// - [guildChannelConverter], which converts [IGuildChannel]s;
/// - [textGuildChannelConverter], which converts [ITextGuildChannel]s;
/// - [voiceGuildChannelConverter], which converts [IVoiceGuildChannel]s;
/// - [stageVoiceChannelConverter], which converts [IStageVoiceGuildChannel]s;
/// - [roleConverter], which converts [IRole]s;
/// - [mentionableConverter], which converts [Mentionable]s.
///
/// You can override these default implementations with your own by calling
/// [CommandsPlugin.addConverter] with your own converter for one of the types mentioned above.
///
/// You might also be interested in:
/// - [CommandsPlugin.addConverter], for adding your own converters to your bot;
/// - [FallbackConverter], for successively trying converters until one succeeds;
/// - [CombineConverter], for piping the output of one converter into another.
class Converter<T> {
  /// The function called to perform the conversion.
  ///
  /// `view` is a view on the current argument string. For text commands, this will contain the
  /// entire content of the message. For Slash Commands, this will contain the content provided by
  /// the user for the current argument.
  ///
  /// This function should not throw if parsing fails, it should instead return `null` to indicate
  /// failure. A [BadInputException] will then be added to [CommandsPlugin.onCommandError] where it
  /// can be handled appropriately.
  final FutureOr<T?> Function(StringView view, IContextData context) convert;

  /// The choices for this type.
  ///
  /// Choices will be the only options selectable in Slash Commands, however text commands might
  /// still pass any content to this converter.
  final Iterable<ArgChoiceBuilder>? choices;

  /// The [Discord Slash Command Argument Type](https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-option-type)
  /// of the type that this converter parses.
  ///
  /// Setting this to [CommandOptionType.subCommand] or [CommandOptionType.subCommandGroup] will
  /// result in an error. Use [ChatGroup] instead.
  final CommandOptionType type;

  /// The type that this converter parses.
  ///
  /// Used by [CommandsPlugin.getConverter] to construct assembled converters.
  final Type output;

  /// A callback called with the [CommandOptionBuilder] created for an option using this converter.
  ///
  /// Can be used to make custom changes to the builder that are not implemented by default.
  final void Function(CommandOptionBuilder)? processOptionCallback;

  /// A function called to provide [autocompletion](https://discord.com/developers/docs/interactions/application-commands#autocomplete)
  /// for arguments of this type.
  ///
  /// This function should return an iterable of options the user can select from, or `null` to
  /// indicate failure. In the event of a failure, the user will see a "options failed to load"
  /// message in their client.
  ///
  /// This function should return at most 25 results and should not throw.
  final FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? autocompleteCallback;

  /// Create a new converter.
  ///
  /// Strongly typing converter variables is recommended (i.e use `Converter<String>(...)` instead
  /// of `Converter(...)`).
  const Converter(
    this.convert, {
    this.choices,
    this.processOptionCallback,
    this.autocompleteCallback,
    this.type = CommandOptionType.string,
  }) : output = T;

  @override
  String toString() => 'Converter<$T>';
}

/// A converter that extends the functionality of an existing converter, piping its output through
/// another function.
///
/// This has the effect of allowing further processing of the output of a converter, for example to
/// transform a [Snowflake] into a [IMember].
///
/// You might also be interested in:
/// - [FallbackConverter], a converter that tries multiple converters successively.
class CombineConverter<R, T> implements Converter<T> {
  /// The converter used to parse the original input to the intermediate type.
  final Converter<R> converter;

  /// The function that transforms the intermediate type into the output type.
  ///
  /// As with normal converters, this function should not throw but can return `null` to indicate
  /// parsing failure.
  final FutureOr<T?> Function(R, IContextData) process;

  @override
  final Type output;

  final void Function(CommandOptionBuilder)? _customProcessOptionCallback;

  @override
  void Function(CommandOptionBuilder)? get processOptionCallback =>
      _customProcessOptionCallback ?? converter.processOptionCallback;

  final FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? _autocompleteCallback;

  @override
  FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? get autocompleteCallback =>
      _autocompleteCallback ?? converter.autocompleteCallback;

  final Iterable<ArgChoiceBuilder>? _choices;
  final CommandOptionType? _type;

  /// Create a new [CombineConverter].
  const CombineConverter(
    this.converter,
    this.process, {
    Iterable<ArgChoiceBuilder>? choices,
    CommandOptionType? type,
    void Function(CommandOptionBuilder)? processOptionCallback,
    FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? autocompleteCallback,
  })  : _choices = choices,
        _type = type,
        output = T,
        _customProcessOptionCallback = processOptionCallback,
        _autocompleteCallback = autocompleteCallback;

  @override
  Iterable<ArgChoiceBuilder>? get choices => _choices ?? converter.choices;

  @override
  CommandOptionType get type => _type ?? converter.type;

  @override
  FutureOr<T?> Function(StringView view, IContextData context) get convert =>
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

/// A converter that successively tries a list of converters until one succeeds.
///
/// Given three converters *a*, *b* and *c*, a [FallbackConverter] will first try to convert the
/// input using *a*, then, if *a* failed, using *b*, then, if *b* failed, using *c*. If all of *a*,
/// *b* and *c* fail, then the [FallbackConverter] will also fail. If at least one of *a*, *b* or
/// *c* succeed, the [FallbackConverter] will return the result of that conversion.
///
/// You might also be interested in:
/// - [CombineConverter], for further processing the output of another converter.
class FallbackConverter<T> implements Converter<T> {
  /// The converters this [FallbackConverter] will attempt to use.
  final Iterable<Converter<T>> converters;

  @override
  final void Function(CommandOptionBuilder)? processOptionCallback;

  @override
  final FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? autocompleteCallback;

  final Iterable<ArgChoiceBuilder>? _choices;
  final CommandOptionType? _type;

  @override
  final Type output;

  /// Create a new [FallbackConverter].
  const FallbackConverter(
    this.converters, {
    Iterable<ArgChoiceBuilder>? choices,
    CommandOptionType? type,
    this.processOptionCallback,
    this.autocompleteCallback,
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
  FutureOr<T?> Function(StringView view, IContextData context) get convert =>
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

String? convertString(StringView view, IContextData context) => view.getQuotedWord();

/// A [Converter] that converts input to a [String].
///
/// This converter returns the next space-separated word in the input, or, if the next word in the
/// input is quoted, the next quoted section of the input.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.string].
const Converter<String> stringConverter = Converter<String>(
  convertString,
  type: CommandOptionType.string,
);

int? convertInt(StringView view, IContextData context) => int.tryParse(view.getQuotedWord());

/// A converter that converts input to various types of numbers, possibly with a minimum or maximum
/// value.
///
/// Note: this converter does not ensure that all values will be in the range `min..max`. [min] and
/// [max] offer purely client-side validation and input from text commands is not validated beyond
/// being a valid number.
///
/// You might also be interested in:
/// - [IntConverter], for converting [int]s;
/// - [DoubleConverter], for converting [double]s.
class NumConverter<T extends num> extends Converter<T> {
  /// The smallest value the user will be allowed to input in the Discord Client.
  final T? min;

  /// The biggest value the user will be allows to input in the Discord Client.
  final T? max;

  /// Create a new [NumConverter].
  const NumConverter(
    T? Function(StringView, IContextData) convert, {
    required CommandOptionType type,
    this.min,
    this.max,
  }) : super(convert, type: type);

  @override
  void Function(CommandOptionBuilder)? get processOptionCallback => (builder) {
        builder.min = min;
        builder.max = max;
      };
}

/// A converter that converts input to [int]s, possibly with a minimum or maximum value.
///
/// Note: this converter does not ensure that all values will be in the range `min..max`. [min] and
/// [max] offer purely client-side validation and input from text commands is not validated beyond
/// being a valid integer.
///
/// You might also be interested in:
/// - [intConverter], the default [IntConverter].
class IntConverter extends NumConverter<int> {
  /// Create a new [IntConverter].
  const IntConverter({
    int? min,
    int? max,
  }) : super(
          convertInt,
          type: CommandOptionType.integer,
          min: min,
          max: max,
        );
}

/// A [Converter] that converts input to an [int].
///
/// This converter attempts to parse the next word or quoted section of the input with [int.parse].
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.integer].
const Converter<int> intConverter = IntConverter();

double? convertDouble(StringView view, IContextData context) =>
    double.tryParse(view.getQuotedWord());

/// A converter that converts input to [double]s, possibly with a minimum or maximum value.
///
/// Note: this converter does not ensure that all values will be in the range `min..max`. [min] and
/// [max] offer purely client-side validation and input from text commands is not validated beyond
/// being a valid double.
///
/// You might also be interested in:
/// - [doubleConverter], the default [DoubleConverter].
class DoubleConverter extends NumConverter<double> {
  /// Create a new [DoubleConverter].
  const DoubleConverter({
    double? min,
    double? max,
  }) : super(
          convertDouble,
          type: CommandOptionType.number,
          min: min,
          max: max,
        );
}

/// A [Converter] that converts input to a [double].
///
/// This converter attempts to parse the next word or quoted section of the input with
/// [double.parse].
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.number].
const Converter<double> doubleConverter = DoubleConverter();

bool? convertBool(StringView view, IContextData context) {
  String word = view.getQuotedWord();

  const Iterable<String> truthy = ['y', 'yes', '+', '1', 'true'];
  const Iterable<String> falsy = ['n', 'no', '-', '0', 'false'];

  const Iterable<String> valid = [...truthy, ...falsy];

  if (valid.contains(word.toLowerCase())) {
    return truthy.contains(word.toLowerCase());
  }

  return null;
}

/// A [Converter] that converts input to a [bool].
///
/// This converter will parse the input to `true` if the next word or quoted section of the input is
/// one of `y`, `yes`, `+`, `1` or `true`. This comparison is case-insensitive.
/// This converter will parse the input to `false` if the next work or quoted section of the input
/// is one of `n`, `no`, `-`, `0` or `false`. This comparison is case-insensitive.
///
/// If the input is not one of the aforementioned words, this converter will fail.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.boolean].
const Converter<bool> boolConverter = Converter<bool>(
  convertBool,
  type: CommandOptionType.boolean,
);

final RegExp _snowflakePattern = RegExp(r'^(?:<(?:@(?:!|&)?|#)([0-9]{15,20})>|([0-9]{15,20}))$');

Snowflake? convertSnowflake(StringView view, IContextData context) {
  String word = view.getQuotedWord();
  if (!_snowflakePattern.hasMatch(word)) {
    return null;
  }

  final RegExpMatch match = _snowflakePattern.firstMatch(word)!;

  // 1st group will catch mentions, second will catch raw IDs
  return Snowflake(match.group(1) ?? match.group(2));
}

/// A converter that converts input to a [Snowflake].
///
/// This converter will parse user mentions, member mentions, channel mentions or raw integers as
/// snowflakes.
const Converter<Snowflake> snowflakeConverter = Converter<Snowflake>(
  convertSnowflake,
);

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
);

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
);

IGuildChannel? snowflakeToGuildChannel(Snowflake snowflake, IContextData context) {
  if (context.guild != null) {
    try {
      return context.guild!.channels.firstWhere((channel) => channel.id == snowflake);
    } on StateError {
      return null;
    }
  }

  return null;
}

IGuildChannel? convertGuildChannel(StringView view, IContextData context) {
  if (context.guild != null) {
    String word = view.getQuotedWord();

    List<IGuildChannel> caseInsensitive = [];
    List<IGuildChannel> partial = [];

    for (final channel in context.guild!.channels) {
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

  return null;
}

/// A converter that converts input to one or more types of [IGuildChannel]s.
///
/// This converter will only allow users to select channels of one of the types in [channelTypes],
/// and then will further only accept channels of type `T`.
///
///
/// Note: this converter does not ensure that all values will conform to [channelTypes].
/// [channelTypes] offers purely client-side validation and input from text commands will not be
/// validated beyond being assignable to `T`.
///
/// You might also be interested in:
/// - [guildChannelConverter], a converter for all [IGuildChannel]s;
/// - [textGuildChannelConverter], a converter for [ITextGuildChannel]s;
/// - [voiceGuildChannelConverter], a converter for [IVoiceGuildChannel]s;
/// - [categoryGuildChannelConverter], a converter for [ICategoryGuildChannel]s;
/// - [stageVoiceChannelConverter], a converter for [IStageVoiceGuildChannel]s.
class GuildChannelConverter<T extends IGuildChannel> implements Converter<T> {
  /// The types of channels this converter allows users to select.
  ///
  /// If this is `null`, all channel types can be selected. Note that only channels which match both
  /// these types *and* `T` will be parsed by this converter.
  final List<ChannelType>? channelTypes;

  final FallbackConverter<IGuildChannel> _internal = const FallbackConverter(
    [
      CombineConverter<Snowflake, IGuildChannel>(snowflakeConverter, snowflakeToGuildChannel),
      Converter<IGuildChannel>(convertGuildChannel),
    ],
    type: CommandOptionType.channel,
  );

  /// Create a new [GuildChannelConverter].
  const GuildChannelConverter(this.channelTypes);

  @override
  Iterable<ArgChoiceBuilder> get choices => [];

  @override
  FutureOr<T?> Function(StringView, IContextData) get convert => (view, context) async {
        IGuildChannel? channel = await _internal.convert(view, context);

        if (channel is T) {
          return channel;
        }

        return null;
      };

  @override
  void Function(CommandOptionBuilder) get processOptionCallback =>
      (builder) => builder.channelTypes = channelTypes;

  @override
  FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? get autocompleteCallback =>
      null;

  @override
  Type get output => T;

  @override
  CommandOptionType get type => CommandOptionType.channel;
}

/// A converter that converts input to an [IGuildChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [IGuildChannel]. If this fails, the channel will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept all channel types.
const GuildChannelConverter<IGuildChannel> guildChannelConverter = GuildChannelConverter(null);

/// A converter that converts input to an [ITextGuildChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [ITextGuildChannel]. If this fails, the channel will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept channels of type [ChannelType.text].
const GuildChannelConverter<ITextGuildChannel> textGuildChannelConverter = GuildChannelConverter([
  ChannelType.text,
]);

/// A converter that converts input to an [IVoiceGuildChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [IVoiceGuildChannel]. If this fails, the channel will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept channels of type [ChannelType.voice].
const GuildChannelConverter<IVoiceGuildChannel> voiceGuildChannelConverter = GuildChannelConverter([
  ChannelType.voice,
]);

/// A converter that converts input to an [ICategoryGuildChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [ICategoryGuildChannel]. If this fails, the channel will be looked up by name in the current
/// guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and it
/// set to accept channels of type [ChannelType.category].
const GuildChannelConverter<ICategoryGuildChannel> categoryGuildChannelConverter =
    GuildChannelConverter([
  ChannelType.category,
]);

/// A converter that converts input to an [IStageVoiceGuildChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [IStageVoiceGuildChannel]. If this fails, the channel will be looked up by name in the current
/// guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept channels of type [ChannelType.guildStage].
const GuildChannelConverter<IStageVoiceGuildChannel> stageVoiceChannelConverter =
    GuildChannelConverter([
  ChannelType.guildStage,
]);

FutureOr<IRole?> snowflakeToRole(Snowflake snowflake, IContextData context) {
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

  return null;
}

FutureOr<IRole?> convertRole(StringView view, IContextData context) async {
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

/// A converter that converts input to an [IRole].
///
/// This will first attempt to parse the input as a snowflake that will then be converted to an
/// [IRole]. If this fails, then the role will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.role].
const Converter<IRole> roleConverter = FallbackConverter<IRole>(
  [
    CombineConverter<Snowflake, IRole>(snowflakeConverter, snowflakeToRole),
    Converter<IRole>(convertRole),
  ],
  type: CommandOptionType.role,
);

/// A converter that converts input to a [Mentionable].
///
/// This will first attempt to convert the input as a member, then as a role.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.mentionable].
const Converter<Mentionable> mentionableConverter = FallbackConverter(
  [
    memberConverter,
    roleConverter,
  ],
  type: CommandOptionType.mentionable,
);

IAttachment? snowflakeToAttachment(Snowflake id, IContextData context) {
  Iterable<IAttachment>? attachments;
  if (context is InteractionChatContext) {
    attachments = context.interaction.resolved?.attachments ?? [];
  } else if (context is MessageChatContext) {
    attachments = context.message.attachments;
  }

  if (attachments == null) {
    return null;
  }

  try {
    return attachments.singleWhere((attachment) => attachment.id == id);
  } on StateError {
    return null;
  }
}

IAttachment? convertAttachment(StringView view, IContextData context) {
  String fileName = view.getQuotedWord();

  Iterable<IAttachment>? attachments;
  if (context is InteractionChatContext) {
    attachments = context.interaction.resolved?.attachments;
  } else if (context is MessageChatContext) {
    attachments = context.message.attachments;
  }

  if (attachments == null) {
    return null;
  }

  Iterable<IAttachment> exactMatch = attachments.where(
    (attachment) => attachment.filename == fileName,
  );

  Iterable<IAttachment> caseInsensitive = attachments.where(
    (attachment) => attachment.filename.toLowerCase() == fileName.toLowerCase(),
  );

  Iterable<IAttachment> partialMatch = attachments.where(
    (attachment) => attachment.filename.toLowerCase().startsWith(fileName.toLowerCase()),
  );

  for (final list in [exactMatch, caseInsensitive, partialMatch]) {
    if (list.length == 1) {
      return list.first;
    }
  }

  return null;
}

/// A converter that converts input to an [IAttachment].
///
/// This will first attempt to parse the input to a snowflake that will then be resolved as the ID
/// of one of the attachments in the message or interaction. If this fails, then the attachment will
/// be looked up by name.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.attachment].
const Converter<IAttachment> attachmentConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, IAttachment>(snowflakeConverter, snowflakeToAttachment),
    Converter(convertAttachment),
  ],
  type: CommandOptionType.attachment,
);

/// Apply a converter to an input and return the result.
///
/// - [commands] is the instance of [CommandsPlugin] used to retrieve the appropriate converter;
/// - [context] is the context to parse arguments in;
/// - [toParse] is the input to the converter;
/// - [expectedType] is the type that should be returned from this function;
/// - [converterOverride] can be specified to use that converter instead of querying [commands] for
///   the converter to use.
///
/// You might also be interested in:
/// - [ICommand.invoke], which parses multiple arguments and executes a command.
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

/// Adds the default converters to an instance of [CommandsPlugin].
///
/// This function is called automatically and you do not need to call it yourself.
///
/// The list of converters this function adds can be found in the [Converter] documentation.
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
    ..addConverter(categoryGuildChannelConverter)
    ..addConverter(stageVoiceChannelConverter)
    ..addConverter(roleConverter)
    ..addConverter(mentionableConverter)
    ..addConverter(attachmentConverter);
}
