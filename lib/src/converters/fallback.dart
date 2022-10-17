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

import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../context/autocomplete_context.dart';
import '../context/base.dart';
import '../mirror_utils/mirror_utils.dart';
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
  final FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? autocompleteCallback;

  final Iterable<ArgChoiceBuilder>? _choices;
  final CommandOptionType? _type;

  final FutureOr<MultiselectOptionBuilder> Function(T)? _toMultiselectOption;

  final FutureOr<ButtonBuilder> Function(T)? _toButton;

  @override
  DartType<T> get output => DartType<T>();

  /// Create a new [FallbackConverter].
  const FallbackConverter(
    this.converters, {
    Iterable<ArgChoiceBuilder>? choices,
    CommandOptionType? type,
    this.processOptionCallback,
    this.autocompleteCallback,
    FutureOr<MultiselectOptionBuilder> Function(T)? toMultiselectOption,
    FutureOr<ButtonBuilder> Function(T)? toButton,
  })  : _choices = choices,
        _type = type,
        _toMultiselectOption = toMultiselectOption,
        _toButton = toButton;

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
  FutureOr<MultiselectOptionBuilder> Function(T)? get toMultiselectOption {
    if (_toMultiselectOption != null) {
      return _toMultiselectOption;
    }

    for (final converter in converters) {
      if (converter.toMultiselectOption != null) {
        return converter.toMultiselectOption;
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
      if (converter.toButton != null) {
        return converter.toButton;
      }
    }

    return null;
  }

  @override
  String toString() => 'FallbackConverter<$T>[converters=${List.of(converters)}]';
}
