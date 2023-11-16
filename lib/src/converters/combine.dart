import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../context/autocomplete_context.dart';
import '../context/base.dart';
import '../util/view.dart';
import 'converter.dart';

/// A converter that extends the functionality of an existing converter, piping its output through
/// another function.
///
/// This has the effect of allowing further processing of the output of a converter, for example to
/// transform a [Snowflake] into a [Member].
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
  final FutureOr<T?> Function(R, ContextData) process;

  @override
  RuntimeType<T> get output => RuntimeType<T>();

  final void Function(CommandOptionBuilder)? _customProcessOptionCallback;

  @override
  void Function(CommandOptionBuilder)? get processOptionCallback =>
      _customProcessOptionCallback ?? converter.processOptionCallback;

  final FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext)?
      _autocompleteCallback;

  @override
  FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext)?
      get autocompleteCallback => _autocompleteCallback ?? converter.autocompleteCallback;

  @override
  final FutureOr<SelectMenuOptionBuilder> Function(T)? toSelectMenuOption;

  @override
  final FutureOr<ButtonBuilder> Function(T)? toButton;

  final Iterable<CommandOptionChoiceBuilder<dynamic>>? _choices;
  final CommandOptionType? _type;

  /// Create a new [CombineConverter].
  const CombineConverter(
    this.converter,
    this.process, {
    Iterable<CommandOptionChoiceBuilder<dynamic>>? choices,
    CommandOptionType? type,
    void Function(CommandOptionBuilder)? processOptionCallback,
    FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext)?
        autocompleteCallback,
    this.toSelectMenuOption,
    this.toButton,
  })  : _choices = choices,
        _type = type,
        _customProcessOptionCallback = processOptionCallback,
        _autocompleteCallback = autocompleteCallback;

  @override
  Iterable<CommandOptionChoiceBuilder<dynamic>>? get choices => _choices ?? converter.choices;

  @override
  CommandOptionType get type => _type ?? converter.type;

  @override
  FutureOr<T?> Function(StringView view, ContextData context) get convert => (view, context) async {
        R? ret = await converter.convert(view, context);

        if (ret != null) {
          return await process(ret, context);
        }
        return null;
      };

  @override
  String toString() => 'CombineConverter<$R, $T>[converter=$converter]';
}
