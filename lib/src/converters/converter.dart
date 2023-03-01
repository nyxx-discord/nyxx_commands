import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:runtime_type/runtime_type.dart';

import '../commands.dart';
import '../context/autocomplete_context.dart';
import '../context/base.dart';
import '../errors.dart';
import '../util/view.dart';
import 'built_in.dart';

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
/// - [mentionableConverter], which converts [Mentionable]s;
/// - [attachmentConverter], which converts [IAttachment]s.
///
/// You can override these default implementations with your own by calling
/// [CommandsPlugin.addConverter] with your own converter for one of the types mentioned above.
///
/// You might also be interested in:
/// - [CommandsPlugin.addConverter], for adding your own converters to your bot;
/// - [FallbackConverter], for successively trying converters until one succeeds;
/// - [CombineConverter], for piping the output of one converter into another;
/// - [SimpleConverter], for creating simple converters.
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
  RuntimeType<T> get output => RuntimeType<T>();

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

  /// A function called to provide [MultiselectOptionBuilder]s that can be used to represent an
  /// element converted by this converter.
  ///
  /// The builder returned by this function should have a value that this converter will be able to
  /// convert.
  ///
  /// You might also be interested in:
  /// - [IInteractiveContext.getSelection] and [IInteractiveContext.getMultiSelection], which make
  ///   use of this function;
  /// - [toButton], similar to this function but for [ButtonBuilder]s.
  final FutureOr<MultiselectOptionBuilder> Function(T)? toMultiselectOption;

  /// A function called to provide [ButtonBuilder]s that can be used to represent an element
  /// converted by this converter.
  ///
  /// You might also be interested in:
  /// - [IInteractiveContext.getButtonSelection], which makes use of this function;
  /// - [toMultiselectOption], similar to this function but for [MultiselectOptionBuilder]s.
  final FutureOr<ButtonBuilder> Function(T)? toButton;

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
    this.toMultiselectOption,
    this.toButton,
  });

  @override
  String toString() => 'Converter<$T>';
}

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
Future<T> parse<T>(
  CommandsPlugin commands,
  IContextData context,
  StringView toParse,
  RuntimeType<T> expectedType, {
  Converter<T>? converterOverride,
}) async {
  Converter<T>? converter = converterOverride ?? commands.getConverter(expectedType);
  if (converter == null) {
    throw NoConverterException(expectedType);
  }

  StringView originalInput = toParse.copy();

  try {
    T? parsed = await converter.convert(toParse, context);

    if (parsed == null) {
      throw ConverterFailedException(converter, originalInput, context);
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
