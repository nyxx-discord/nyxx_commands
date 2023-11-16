import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../context/autocomplete_context.dart';
import '../context/base.dart';
import '../util/view.dart';
import 'converter.dart';

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
  final FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext)?
      autocompleteCallback;

  final Iterable<CommandOptionChoiceBuilder<dynamic>>? _choices;
  final CommandOptionType? _type;

  final FutureOr<SelectMenuOptionBuilder> Function(T)? _toSelectMenuOption;

  final FutureOr<ButtonBuilder> Function(T)? _toButton;

  @override
  RuntimeType<T> get output => RuntimeType<T>();

  /// Create a new [FallbackConverter].
  const FallbackConverter(
    this.converters, {
    Iterable<CommandOptionChoiceBuilder<dynamic>>? choices,
    CommandOptionType? type,
    this.processOptionCallback,
    this.autocompleteCallback,
    FutureOr<SelectMenuOptionBuilder> Function(T)? toSelectMenuOption,
    FutureOr<ButtonBuilder> Function(T)? toButton,
  })  : _choices = choices,
        _type = type,
        _toSelectMenuOption = toSelectMenuOption,
        _toButton = toButton;

  @override
  Iterable<CommandOptionChoiceBuilder<dynamic>>? get choices {
    if (_choices != null) {
      return _choices;
    }

    List<CommandOptionChoiceBuilder<dynamic>> allChoices = [];

    for (final converter in converters) {
      Iterable<CommandOptionChoiceBuilder<dynamic>>? converterChoices = converter.choices;

      if (converterChoices == null) {
        return null;
      }

      for (final choice in converterChoices) {
        CommandOptionChoiceBuilder<dynamic> existing =
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
  FutureOr<T?> Function(StringView view, ContextData context) get convert => (view, context) async {
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
  FutureOr<SelectMenuOptionBuilder> Function(T)? get toSelectMenuOption {
    if (_toSelectMenuOption != null) {
      return _toSelectMenuOption;
    }

    for (final converter in converters) {
      if (converter.toSelectMenuOption is FutureOr<SelectMenuOptionBuilder> Function(T)) {
        return converter.toSelectMenuOption;
      }
    }

    return null;
  }

  @override
  FutureOr<ButtonBuilder> Function(T)? get toButton {
    if (_toButton != null) {
      return _toButton;
    }

    for (final converter in converters) {
      if (converter.toButton is FutureOr<ButtonBuilder> Function(T)) {
        return converter.toButton;
      }
    }

    return null;
  }

  @override
  String toString() => 'FallbackConverter<$T>[converters=${List.of(converters)}]';
}
