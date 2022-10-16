import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/autocomplete_context.dart';
import '../../context/base.dart';
import '../../converters/fallback.dart';
import '../../mirror_utils/mirror_utils.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import 'snowflake.dart';

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

    if (word.startsWith('#')) {
      word = word.substring(1);
    }

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
  DartType<T> get output => DartType<T>();

  @override
  CommandOptionType get type => CommandOptionType.channel;

  @override
  MultiselectOptionBuilder Function(T) get toMultiselectOption => (channel) {
        MultiselectOptionBuilder builder = MultiselectOptionBuilder(
          channel.name,
          channel.id.toString(),
        );

        if (channel is ITextGuildChannel) {
          builder.description = channel.topic;
        }

        return builder;
      };

  @override
  ButtonBuilder Function(T) get toButton => (channel) => ButtonBuilder(
        '#${channel.name}',
        '',
        ButtonStyle.primary,
      );
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
