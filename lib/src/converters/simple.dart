import 'package:fuzzywuzzy/fuzzywuzzy.dart' as fuzzy;
import 'package:nyxx_interactions/src/builders/arg_choice_builder.dart';
import 'package:nyxx_interactions/src/builders/command_option_builder.dart';
import 'package:nyxx_interactions/src/models/command_option.dart';

import '../context/autocomplete_context.dart';
import '../context/chat_context.dart';
import '../util/view.dart';
import 'converter.dart';

abstract class SimpleConverter<T> implements Converter<T> {
  Iterable<T> Function() get provider;
  String Function(T) get stringify;

  final T? Function(StringView, IChatContext)? reviver;

  final int sensitivity;

  @override
  final Type output;

  @override
  CommandOptionType get type => CommandOptionType.string;

  const SimpleConverter._({required this.sensitivity, required this.output, this.reviver});

  const factory SimpleConverter({
    required Iterable<T> Function() provider,
    required String Function(T) stringify,
    int sensitivity,
    T? Function(StringView, IChatContext) reviver,
  }) = _DynamicSimpleConverter;

  const factory SimpleConverter.fixed({
    required List<T> elements,
    required String Function(T) stringify,
    int sensitivity,
    T? Function(StringView, IChatContext) reviver,
  }) = _FixedSimpleConverter;

  @override
  Iterable<ArgChoiceBuilder>? Function(AutocompleteContext)? get autocompleteCallback =>
      (context) => fuzzy
          .extractTop(
            query: context.currentValue,
            choices: provider().map(stringify).toList(),
            limit: 25,
            cutoff: sensitivity,
          )
          .map((e) => ArgChoiceBuilder(e.choice, e.choice));

  @override
  T? Function(StringView view, IChatContext context) get convert => (view, context) {
        try {
          return fuzzy
              .extractOne(
                query: view.getQuotedWord(),
                choices: provider().toList(),
                getter: stringify,
                cutoff: sensitivity,
              )
              .choice;
        } on StateError {
          // No elements matched query, try to revive the input.
          // Make sure to undo the call to `getQuotedWord()`.
          return reviver?.call(view..undo(), context);
        }
      };

  @override
  Iterable<ArgChoiceBuilder>? get choices => null;

  @override
  void Function(CommandOptionBuilder)? get processOptionCallback => null;
}

class _DynamicSimpleConverter<T> extends SimpleConverter<T> {
  @override
  final Iterable<T> Function() provider;

  @override
  final String Function(T) stringify;

  const _DynamicSimpleConverter({
    required this.provider,
    required this.stringify,
    super.sensitivity = 50,
    super.reviver,
  }) : super._(output: T);
}

class _FixedSimpleConverter<T> extends SimpleConverter<T> {
  final List<T> elements;

  @override
  final String Function(T) stringify;

  const _FixedSimpleConverter({
    required this.elements,
    required this.stringify,
    super.sensitivity = 50,
    super.reviver,
  }) : super._(output: T);

  @override
  Iterable<T> Function() get provider => () => elements;

  @override
  Iterable<ArgChoiceBuilder>? Function(AutocompleteContext)? get autocompleteCallback =>
      // Don't autocomplete if we have less than 25 elements because we will use choices instead.
      elements.length > 25 ? super.autocompleteCallback : null;

  @override
  Iterable<ArgChoiceBuilder>? get choices =>
      // Only use choices if we have less than 26 elements (maximum of 25 choices).
      elements.length <= 25 ? elements.map(stringify).map((e) => ArgChoiceBuilder(e, e)) : null;
}
