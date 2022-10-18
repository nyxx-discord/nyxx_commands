import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../converter.dart';

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

  @override
  MultiselectOptionBuilder Function(T) get toMultiselectOption => (n) => MultiselectOptionBuilder(
        n.toString(),
        n.toString(),
      );

  @override
  ButtonBuilder Function(T) get toButton => (n) => ButtonBuilder(
        n.toString(),
        '',
        ButtonStyle.primary,
      );
}

int? convertInt(StringView view, IContextData context) => int.tryParse(view.getQuotedWord());

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
