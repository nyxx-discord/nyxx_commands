import 'dart:async';

import 'package:fuzzywuzzy/fuzzywuzzy.dart' as fuzzy;
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../context/autocomplete_context.dart';
import '../context/base.dart';
import '../mirror_utils/mirror_utils.dart';
import '../util/view.dart';
import 'converter.dart';

/// A basic wrapper around a converter, providing an easy way to create custom converters.
///
/// This class allows you to create a custom converter by simply specifying a function to retrieve
/// the available elements to convert and a function to convert elements to a [String] displayed to
/// the user.
///
/// This converter provides the core converter functionality as well as autocompletion and, if
/// [SimpleConverter.fixed] is used, command parameter choices.
///
/// You might also be interested in:
/// - [Converter], the base class for creating custom converters.
/// - [FallbackConverter] and [CombineConverter], two other helpers for creating custom converters.
abstract class SimpleConverter<T> implements Converter<T> {
  /// A function called to retrieve the available elements to convert.
  ///
  /// This should return an iterable of all the instances of `T` that this converter should allow to
  /// be returned. It does not have to always return the same number of instances, and will be
  /// called for each new operation requested from this converter.
  FutureOr<Iterable<T>> Function(IContextData) get provider;

  /// A function called to convert elements into [String]s that can be displayed in the Discord
  /// client.
  ///
  /// This function should return a unique textual representation for each element [provider]
  /// returns. It should be consistent (that is, if `a == b`, `stringify(a) == stringify(b)`) or the
  /// converter might fail unexpectedly.
  String Function(T) get stringify;

  /// A function called if this converter fails to convert the input.
  ///
  /// You can provide additional logic here to convert inputs that would otherwise fail. When this
  /// function is called, it can either return an instance of `T` which will be returned from this
  /// converter or `null`, in which case the converter will fail.
  final T? Function(StringView, IContextData)? reviver;

  /// The sensitivity of this converter.
  ///
  /// The sensitivity of a [SimpleConverter] determines how similar the input must be to the
  /// [String] returned by [stringify] for this converter to succeed.
  ///
  /// If [sensitivity] is `0`, this converter will always succeed with the element most similar to
  /// the input provided [provider] at least one element. If [sensitivity] is `100`, this converter
  /// will only succeed if the input matches exactly with one of the elements.
  final int sensitivity;

  @override
  DartType<T> get output => DartType<T>();

  @override
  CommandOptionType get type => CommandOptionType.string;

  final FutureOr<MultiselectOptionBuilder> Function(T)? _toMultiSelectOption;
  final FutureOr<ButtonBuilder> Function(T)? _toButton;

  const SimpleConverter._({
    required this.sensitivity,
    this.reviver,
    FutureOr<MultiselectOptionBuilder> Function(T)? toMultiSelectOption,
    FutureOr<ButtonBuilder> Function(T)? toButton,
  })  : _toMultiSelectOption = toMultiSelectOption,
        _toButton = toButton;

  /// Create a new [SimpleConverter].
  ///
  /// If you want this instance to be `const` (for use with @[UseConverter]), [provider] and
  /// [stringify] must be top-level or static functions. Function literals are not `const`, so they
  /// cannot be used in a constant creation expression.
  const factory SimpleConverter({
    required Iterable<T> Function(IContextData) provider,
    required String Function(T) stringify,
    int sensitivity,
    T? Function(StringView, IContextData) reviver,
  }) = _DynamicSimpleConverter<T>;

  /// Create a new [SimpleConverter] which converts an unchanging number of elements.
  ///
  /// This differs from a normal [SimpleConverter] in that it will use parameter choices instead
  /// of autocompletion if the number of elements is small enough. If the number of elements is not
  /// small enough to use choices, the normal [SimpleConverter] behavior is used instead.
  const factory SimpleConverter.fixed({
    required List<T> elements,
    required String Function(T) stringify,
    int sensitivity,
    T? Function(StringView, IContextData) reviver,
  }) = _FixedSimpleConverter<T>;

  @override
  Future<Iterable<ArgChoiceBuilder>>? Function(AutocompleteContext)? get autocompleteCallback =>
      (context) async => fuzzy
          .extractTop(
            query: context.currentValue,
            choices: (await provider(context)).map(stringify).toList(),
            limit: 25,
            cutoff: sensitivity,
          )
          .map((e) => ArgChoiceBuilder(e.choice, e.choice));

  @override
  Future<T?> Function(StringView view, IContextData context) get convert => (view, context) async {
        try {
          return fuzzy
              .extractOne(
                query: view.getQuotedWord(),
                choices: (await provider(context)).toList(),
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
  FutureOr<MultiselectOptionBuilder> Function(T)? get toMultiselectOption =>
      _toMultiSelectOption ??
      (element) {
        String value = stringify(element);

        return MultiselectOptionBuilder(value, value);
      };

  @override
  FutureOr<ButtonBuilder> Function(T)? get toButton =>
      _toButton ??
      (element) => ButtonBuilder(
            stringify(element),
            '',
            ButtonStyle.primary,
          );

  @override
  Iterable<ArgChoiceBuilder>? get choices => null;

  @override
  void Function(CommandOptionBuilder)? get processOptionCallback => null;
}

class _DynamicSimpleConverter<T> extends SimpleConverter<T> {
  @override
  final Iterable<T> Function(IContextData) provider;

  @override
  final String Function(T) stringify;

  const _DynamicSimpleConverter({
    required this.provider,
    required this.stringify,
    super.sensitivity = 50,
    super.reviver,
    super.toMultiSelectOption,
    super.toButton,
  }) : super._();
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
    super.toMultiSelectOption,
    super.toButton,
  }) : super._();

  @override
  Iterable<T> Function(IContextData) get provider => (_) => elements;

  @override
  Future<Iterable<ArgChoiceBuilder>>? Function(AutocompleteContext)? get autocompleteCallback =>
      // Don't autocomplete if we have less than 25 elements because we will use choices instead.
      elements.length > 25 ? super.autocompleteCallback : null;

  @override
  Iterable<ArgChoiceBuilder>? get choices =>
      // Only use choices if we have less than 26 elements (maximum of 25 choices).
      elements.length <= 25 ? elements.map(stringify).map((e) => ArgChoiceBuilder(e, e)) : null;
}
