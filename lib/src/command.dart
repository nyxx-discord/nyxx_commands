part of nyxx_commands;

/// An enum used to specify how a [Command] can be executed.
enum CommandType {
  /// Only allow execution by message.
  ///
  /// [textOnly] commands will not be registered as a slash command to Discord.
  textOnly,

  /// Only allow execution by slash command.
  slashOnly,

  /// Do not restrict execution.
  all,
}

/// A [RegExp] that all command names must match
final RegExp commandNameRegexp = RegExp(r'^[\w-]{1,32}$', unicode: true);

/// A [Command] is a function bound to a name and arguments.
///
/// [Command]s can be text-only (meaning they can only be executed through sending a message with
/// the bot's prefix) or slash-only (meaning they can only be executed through the means of a slash
/// command). They can also be both, meaning they can be used both as a text and as a slash command.
///
/// Note that text-only commands can be [Group]s containing slash commands and vice versa, but slash
/// commands cannot be groups containing other slash commands due to
/// [limitations on Discord](https://discord.com/developers/docs/interactions/application-commands#subcommands-and-subcommand-groups).
class Command with GroupMixin {
  /// The short name of this command, i.e without parent names.
  @override
  final String name;

  /// A [List] of short names this command is aliased to.
  @override
  final List<String> aliases;

  /// A description of this command.
  @override
  final String description;

  /// The type of the command.
  ///
  /// A command's type indicates how it can be invoked; text-only commands can only be executed by
  /// sending a text message on Discord and slash commands can only be invoked by executing a slash
  /// command on Discord.
  ///
  /// Note that a command's type does not influence what type of children a command can have.
  final CommandType type;

  /// The [Function] that is called when this command is invoked.
  ///
  /// Any uncaught [Exception]s thrown from this function will be caught and sent to the relevant
  /// bot's [Bot.onCommandError].
  final Function execute;

  /// Similar to [checks] but only applies to this command.
  final List<Check> singleChecks = [];

  late final MethodMirror _mirror;
  late final List<ParameterMirror> _arguments;
  late final int _requiredArguments;
  final List<String> _orderedArgumentNames = [];
  final Map<String, Type> _mappedArgumentTypes = {};
  final Map<String, ParameterMirror> _mappedArgumentMirrors = {};
  final Map<String, Description> _mappedDescriptions = {};

  /// Create a new [Command].
  ///
  /// [name] must match [commandNameRegexp] or an [InvalidNameException] will be thrown.
  /// [execute] must be a function whose first parameter must be of type [Context].
  Command(
    this.name,
    this.description,
    this.execute, {
    this.aliases = const [],
    this.type = CommandType.all,
    List<GroupMixin> children = const [],
    List<Check> checks = const [],
    List<Check> singleChecks = const [],
  }) {
    if (!commandNameRegexp.hasMatch(name)) {
      throw InvalidNameException(name);
    }

    _loadArguments(execute, Context);

    for (final child in children) {
      registerChild(child);
    }

    for (final check in checks) {
      super.check(check);
    }

    for (final singleCheck in singleChecks) {
      this.singleCheck(singleCheck);
    }
  }

  /// Create a new text-only [Command].
  ///
  /// [name] must match [commandNameRegexp] or an [InvalidNameException] will be thrown.
  /// [execute] must be a function whose first parameter must be of type [MessageContext].
  Command.textOnly(
    this.name,
    this.description,
    this.execute, {
    this.aliases = const [],
    List<GroupMixin> children = const [],
    List<Check> checks = const [],
    List<Check> singleChecks = const [],
  }) : type = CommandType.textOnly {
    if (!commandNameRegexp.hasMatch(name)) {
      throw InvalidNameException(name);
    }

    _loadArguments(execute, MessageContext);

    for (final child in children) {
      registerChild(child);
    }

    for (final check in checks) {
      super.check(check);
    }

    for (final singleCheck in singleChecks) {
      this.singleCheck(singleCheck);
    }
  }

  /// Create a new slash-only [Command].
  ///
  /// [name] must match [commandNameRegexp] or an [InvalidNameException] will be thrown.
  /// [execute] must be a function whose first parameter must be of type [InteractionContext].
  Command.slashOnly(
    this.name,
    this.description,
    this.execute, {
    this.aliases = const [],
    List<GroupMixin> children = const [],
    List<Check> checks = const [],
    List<Check> singleChecks = const [],
  }) : type = CommandType.slashOnly {
    if (!commandNameRegexp.hasMatch(name)) {
      throw InvalidNameException('Invalid name "$name" for command');
    }

    _loadArguments(execute, InteractionContext);

    for (final child in children) {
      registerChild(child);
    }

    for (final check in checks) {
      super.check(check);
    }

    for (final singleCheck in singleChecks) {
      this.singleCheck(singleCheck);
    }
  }

  void _loadArguments(Function fn, Type contextType) {
    _mirror = (reflect(fn) as ClosureMirror).function;

    List<ParameterMirror> arguments = _mirror.parameters;

    if (arguments.isEmpty) {
      throw InvalidFunctionException('execute function must have at least one argument');
    }

    if (!reflectType(contextType).isAssignableTo(arguments[0].type)) {
      throw InvalidFunctionException(
          'The first parameter to the execute function must be of type $contextType');
    }

    // Skip context argument
    _arguments = List.of(arguments.skip(1));
    _requiredArguments = _arguments.fold(0, (i, e) {
      if (e.isOptional) {
        return i;
      }
      return i + 1;
    });

    for (final parametrer in _arguments) {
      if (!parametrer.type.hasReflectedType) {
        throw InvalidFunctionException('execute function must have reflected parameter types');
      }
      if (parametrer.type.reflectedType == dynamic) {
        throw InvalidFunctionException('execute function cannot have dynamic parameter types');
      }
      if (parametrer.isNamed) {
        throw InvalidFunctionException('execute function cannot have named parameters');
      }
      if (parametrer.metadata.where((element) => element.reflectee is Description).length > 1) {
        throw InvalidFunctionException('execute function may not have more than one description '
            'per argument');
      }
    }

    for (final argument in _arguments) {
      String kebabCaseName = convertToKebabCase(MirrorSystem.getName(argument.simpleName));

      if (!commandNameRegexp.hasMatch(kebabCaseName)) {
        throw InvalidNameException('Invalid converted name "$kebabCaseName" for argument');
      }

      Iterable<Description> descriptions = argument.metadata
          .where((element) => element.reflectee is Description)
          .map((descriptionMirror) => descriptionMirror.reflectee)
          .cast<Description>();

      Description description;
      if (descriptions.isNotEmpty) {
        description = descriptions.first;
      } else {
        description = const Description('No description provided');
      }

      if (description.value.isEmpty || description.value.length > 100) {
        throw InvalidDescriptionException(description.value);
      }

      _mappedDescriptions[kebabCaseName] = description;
      _mappedArgumentTypes[kebabCaseName] = argument.type.reflectedType;
      _mappedArgumentMirrors[kebabCaseName] = argument;
      _orderedArgumentNames.add(kebabCaseName);
    }
  }

  /// Parse arguments contained in the context and call [execute].
  ///
  /// If not enough arguments are provided, [NotEnoughArgumentsException] is thrown. Remaining
  /// data after all optional and non-optional arguments have been parsed is discarded.
  /// If an exception is thrown from [execute], it is caught and rethrown as an [UncaughtException].
  ///
  /// The arguments, if the context is a [MessageContext], will be parsed using the relevant
  /// converter on the [bot]. If no converter is found, the command execution will fail.
  ///
  /// If the context is an [InteractionContext], the arguments will either be parsed from their raw
  /// string representations or will not be parsed at all if the type received from the API is
  /// correct.
  Future<void> invoke(Bot bot, Context context) async {
    List arguments = <dynamic>[];

    if (context is MessageContext) {
      StringView argumentsView = StringView(context.rawArguments);

      for (final argumentName in _orderedArgumentNames) {
        if (argumentsView.eof) {
          break;
        }

        Type expectedType = _mappedArgumentTypes[argumentName]!;

        arguments.add(await parse(bot, context, argumentsView, expectedType));
      }
    } else if (context is InteractionContext) {
      for (final argumentName in _orderedArgumentNames) {
        if (!context.rawArguments.containsKey(argumentName)) {
          arguments.add(_mappedArgumentMirrors[argumentName]!.defaultValue?.reflectee);
          continue;
        }

        dynamic rawArgument = context.rawArguments[argumentName]!;
        Type expectedType = _mappedArgumentTypes[argumentName]!;

        if (reflect(rawArgument).type.isAssignableTo(reflectType(expectedType))) {
          arguments.add(rawArgument);
          continue;
        }

        arguments.add(await parse(bot, context, StringView(rawArgument.toString()), expectedType));
      }
    }

    if (arguments.length < _requiredArguments) {
      throw NotEnoughArgumentsException(
        arguments.length,
        _requiredArguments,
      );
    }

    context.arguments = arguments;

    for (final check in [...checks, ...singleChecks]) {
      if (!await check.check(context)) {
        throw CheckFailedException(context);
      }
    }

    try {
      Function.apply(execute, [context, ...arguments]);
    } on Exception catch (e) {
      throw UncaughtException(e);
    }
  }

  @override
  List<CommandOptionBuilder> getOptions(Bot bot) {
    if (type != CommandType.textOnly) {
      if (depth > 2) {
        throw SlashException('Slash commands may at most be two layers deep');
      }

      List<CommandOptionBuilder> options = [];

      for (final mirror in _arguments) {
        String name = convertToKebabCase(MirrorSystem.getName(mirror.simpleName));

        options.add(CommandOptionBuilder(
          discordTypes[mirror.type.reflectedType] ?? CommandOptionType.string,
          name,
          _mappedDescriptions[name]!.value,
          required: !mirror.isOptional,
          choices: bot.converterFor(mirror.type.reflectedType)?.choices?.toList(),
        ));
      }

      return options;
    } else {
      // Text-only commands might have children which are slash commands
      return super.getOptions(bot);
    }
  }

  @override
  void registerChild(GroupMixin child) {
    if (type != CommandType.textOnly) {
      if (child.hasSlashCommand || (child is Command && child.type != CommandType.textOnly)) {
        throw SlashException('Slash commands cannot have slash command decendants');
      }
    }

    super.registerChild(child);
  }

  /// Add a check to this commands [singleChecks].
  void singleCheck(Check check) => singleChecks.add(check);

  @override
  String toString() => 'Command[name="$name", fullName="$fullName"]';
}
