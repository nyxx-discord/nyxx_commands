import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../../context/autocomplete_context.dart';
import '../../context/base.dart';
import '../../converters/fallback.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import 'snowflake.dart';

Future<GuildChannel?> snowflakeToGuildChannel(Snowflake snowflake, ContextData context) async {
  if (context.guild != null) {
    try {
      final channel = await context.client.channels[snowflake].get();

      if (channel is GuildChannel && channel.guildId == context.guild!.id) {
        return channel;
      }
    } on HttpResponseError {
      return null;
    }
  }

  return null;
}

Future<GuildChannel?> convertGuildChannel(StringView view, ContextData context) async {
  if (context.guild != null) {
    String word = view.getQuotedWord();

    if (word.startsWith('#')) {
      word = word.substring(1);
    }

    List<GuildChannel> caseInsensitive = [];
    List<GuildChannel> partial = [];

    for (final channel in await context.guild!.fetchChannels()) {
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

/// A converter that converts input to one or more types of [GuildChannel]s.
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
/// - [guildChannelConverter], a converter for all [GuildChannel]s;
/// - [textGuildChannelConverter], a converter for [GuildTextChannel]s;
/// - [voiceGuildChannelConverter], a converter for [GuildVoiceChannel]s;
/// - [categoryGuildChannelConverter], a converter for [GuildCategory]s;
/// - [stageVoiceChannelConverter], a converter for [GuildStageChannel]s.
class GuildChannelConverter<T extends GuildChannel> implements Converter<T> {
  /// The types of channels this converter allows users to select.
  ///
  /// If this is `null`, all channel types can be selected. Note that only channels which match both
  /// these types *and* `T` will be parsed by this converter.
  final List<ChannelType>? channelTypes;

  final FallbackConverter<GuildChannel> _internal = const FallbackConverter(
    [
      CombineConverter<Snowflake, GuildChannel>(snowflakeConverter, snowflakeToGuildChannel),
      Converter<GuildChannel>(convertGuildChannel),
    ],
    type: CommandOptionType.channel,
  );

  /// Create a new [GuildChannelConverter].
  const GuildChannelConverter(this.channelTypes);

  @override
  Iterable<CommandOptionChoiceBuilder<dynamic>> get choices => [];

  @override
  FutureOr<T?> Function(StringView, ContextData) get convert => (view, context) async {
        GuildChannel? channel = await _internal.convert(view, context);

        if (channel is T) {
          return channel;
        }

        return null;
      };

  @override
  void Function(CommandOptionBuilder) get processOptionCallback => (builder) => builder.channelTypes = channelTypes;

  @override
  FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext)? get autocompleteCallback => null;

  @override
  RuntimeType<T> get output => RuntimeType<T>();

  @override
  CommandOptionType get type => CommandOptionType.channel;

  @override
  SelectMenuOptionBuilder Function(T) get toSelectMenuOption => (channel) => SelectMenuOptionBuilder(
        label: channel.name,
        value: channel.id.toString(),
        description: channel is GuildTextChannel ? channel.topic : null,
      );

  @override
  ButtonBuilder Function(T) get toButton => (channel) => ButtonBuilder(
        style: ButtonStyle.primary,
        label: '#${channel.name}',
        customId: '',
      );
}

/// A converter that converts input to a [GuildChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [GuildChannel]. If this fails, the channel will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept all channel types.
const GuildChannelConverter<GuildChannel> guildChannelConverter = GuildChannelConverter(null);

/// A converter that converts input to an [GuildTextChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [GuildTextChannel]. If this fails, the channel will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept channels of type [ChannelType.guildText].
const GuildChannelConverter<GuildTextChannel> textGuildChannelConverter = GuildChannelConverter([
  ChannelType.guildText,
]);

/// A converter that converts input to an [GuildVoiceChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [GuildVoiceChannel]. If this fails, the channel will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept channels of type [ChannelType.guildVoice].
const GuildChannelConverter<GuildVoiceChannel> voiceGuildChannelConverter = GuildChannelConverter([
  ChannelType.guildVoice,
]);

/// A converter that converts input to an [GuildCategory].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [GuildCategory]. If this fails, the channel will be looked up by name in the current
/// guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and it
/// set to accept channels of type [ChannelType.guildCategory].
const GuildChannelConverter<GuildCategory> categoryGuildChannelConverter = GuildChannelConverter([
  ChannelType.guildCategory,
]);

/// A converter that converts input to an [GuildStageChannel].
///
/// This will first attempt to parse the input as a [Snowflake] that will then be converted to an
/// [GuildStageChannel]. If this fails, the channel will be looked up by name in the current
/// guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.channel] and is
/// set to accept channels of type [ChannelType.guildStageVoice].
const GuildChannelConverter<GuildStageChannel> stageVoiceChannelConverter = GuildChannelConverter([
  ChannelType.guildStageVoice,
]);
