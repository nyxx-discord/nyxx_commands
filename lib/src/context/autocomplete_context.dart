import 'package:nyxx/nyxx.dart';

import '../commands/chat_command.dart';
import '../converters/converter.dart' as converters show parse;
import '../errors.dart';
import '../mirror_utils/mirror_utils.dart';
import '../util/view.dart';
import 'base.dart';

/// Represents a context in which an autocomplete event was triggered.
class AutocompleteContext extends ContextBase implements InteractionContextData {
  @override
  final ApplicationCommandAutocompleteInteraction interaction;

  /// The option that the user is currently filling in.
  ///
  /// Other options might have already been filled in and are accessible through [interaction].
  final InteractionOption option;

  /// The value the user has put in [option] so far.
  ///
  /// This can be empty. It will generally not contain malformed data, but care should still be
  /// taken. Read [the official documentation](https://discord.com/developers/docs/interactions/application-commands#autocomplete)
  /// for more.
  ///
  /// You might also be interested in:
  /// - [parse], for parsing the current value.
  final String currentValue;

  /// A map containing the arguments and the values that the user has inputted so far.
  ///
  /// The keys of this map depend on the names of the arguments set in [command]. If a user has not
  /// yet filled in an argument, it will not be present in this map.
  ///
  /// The values might contain partial data.
  late final Map<String, String> existingArguments = Map.fromEntries(
    interaction.data.options!.map((option) => MapEntry(option.name, option.value.toString())),
  );

  /// A map containing the arguments of [command] and their value, if the user has inputted a value
  /// for them.
  ///
  /// The keys of this map depend on the names of the arguments set in [command].
  ///
  /// The values might contain partial data.
  late final Map<String, String?> arguments;

  /// The command for which arguments are being auto-completed.
  final ChatCommand command;

  late final FunctionData _functionData = loadFunctionData(command.execute);

  /// Create a new [AutocompleteContext].
  AutocompleteContext({
    required this.command,
    required this.interaction,
    required this.option,
    required this.currentValue,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  }) {
    ApplicationCommand command = commands.registeredCommands.singleWhere(
      (element) => element.id == interaction.data.id,
    );

    arguments = Map.fromIterable(
      command.options!.map((option) => option.name),
      value: (option) => existingArguments[option],
    );
  }

  /// Whether the user has inputted a value for an argument with the name [name].
  bool hasArgument(String name) => existingArguments.containsKey(name);

  /// Attempts to parse the current value of this context as a value of type `T`.
  ///
  /// If `T` is not a supertype of the type of the parameter in the command callback, an exception
  /// is thrown.
  ///
  /// You might also be interested in:
  /// - [parseNamed], for parsing an arbitrary option;
  /// - [parseWithType], for parsing an argument with a given type.
  Future<T?> parse<T>() => parseNamed(option.name);

  /// Attempts to parse the value of the option [name] to a value of type `T`.
  ///
  /// If `T` is not a supertype of the type of the parameter [name] in the command callback, an
  /// exception is thrown.
  ///
  /// If the user has not provided a value for the option [name], `null` is returned.
  ///
  /// If no parameter with the name [name] exists in the command callback, an exception is thrown.
  ///
  /// You might also be interested in:
  /// - [parse], for parsing the current option.
  Future<T?> parseNamed<T>(String name) async {
    ParameterData<dynamic> parameterData = _functionData.parametersData.singleWhere(
      (element) => element.name == name,
      orElse: () => throw CommandsException(
        'No option with name "$name" found in command ${command.fullName}',
      ),
    );

    if (!RuntimeType<T>().isSupertypeOf(parameterData.type)) {
      throw CommandsException('Type $T is not a supertype of ${parameterData.type}');
    }

    String? value = arguments[parameterData.name];

    if (value == null) {
      return null;
    }

    return converters
        .parse(
          commands,
          this,
          StringView(value, isRestBlock: true),
          parameterData.type,
        )
        .then((value) => value as T);
  }

  /// Parses the first option in the command callback with type `T`.
  ///
  /// If the user has not yet provided a value for that option, `null` is returned.
  ///
  /// If no option of type `T` is found, an exception is thrown.
  ///
  /// You might also be interested in:
  /// - [parseNamed], for parsing an option by name.
  Future<T?> parseWithType<T>() => parseAllWithType<T>().firstWhere(
        (element) => true,
        orElse: () => throw CommandsException(
          'No parameter with type $T found in command ${command.fullName}',
        ),
      );

  /// Finds all the arguments with a type of `T` in the command callback and parses them.
  ///
  /// The values are ordered as they appear in the command callback.
  ///
  /// If the user has not yet provided a value, `null` is added to the stream instead.
  ///
  /// You might also be interested in:
  /// - [parseWithType], for parsing a single value with a given type.
  Stream<T?> parseAllWithType<T>() {
    RuntimeType<T> type = RuntimeType<T>();

    return Stream.fromIterable(
      _functionData.parametersData.where((element) => element.type.isSubtypeOf(type)),
    ).asyncMap(
      (parameter) {
        String? value = arguments[parameter.name];

        if (value == null) {
          return null;
        }

        return converters
            .parse(
              commands,
              this,
              StringView(value, isRestBlock: true),
              parameter.type,
            )
            .then((value) => value as T);
      },
    );
  }
}
