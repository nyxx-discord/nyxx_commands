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
import 'dart:mirrors';

import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../context/context.dart';
import '../converters/converter.dart';
import '../errors.dart';
import '../util/util.dart';
import '../util/view.dart';
import 'group.dart';

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

  /// A [Iterable] of short names this command is aliased to.
  @override
  final Iterable<String> aliases;

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
  /// bot's [CommandsPlugin.onCommandError].
  final Function execute;

  /// Similar to [checks] but only applies to this command.
  final List<AbstractCheck> singleChecks = [];

  /// Whether to set the EPHEMERAL flag in the original response to interaction events.
  ///
  /// Has no effect for [CommandType.textOnly] commands.
  /// If [CommandsOptions.autoAcknowledgeInteractions] is `true`, this will override
  /// [CommandsOptions.hideOriginalResponse].
  final bool? hideOriginalResponse;

  late final MethodMirror _mirror;
  late final Iterable<ParameterMirror> _arguments;
  late final int _requiredArguments;
  final List<String> _orderedArgumentNames = [];
  final Map<String, Type> _mappedArgumentTypes = {};
  final Map<String, ParameterMirror> _mappedArgumentMirrors = {};
  final Map<String, Description> _mappedDescriptions = {};
  final Map<String, Choices> _mappedChoices = {};
  final Map<String, UseConverter> _mappedConverterOverrides = {};

  /// Create a new [Command].
  ///
  /// [name] must match [commandNameRegexp] or an [CommandRegistrationError] will be thrown.
  /// [execute] must be a function whose first parameter must be of type [Context].
  Command(
    String name,
    String description,
    Function execute, {
    List<String> aliases = const [],
    CommandType type = CommandType.all,
    Iterable<GroupMixin> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    bool? hideOriginalResponse,
  }) : this._(
          name,
          description,
          execute,
          Context,
          aliases: aliases,
          type: type,
          children: children,
          checks: checks,
          singleChecks: singleChecks,
          hideOriginalResponse: hideOriginalResponse,
        );

  /// Create a new text-only [Command].
  ///
  /// [name] must match [commandNameRegexp] or an [CommandRegistrationError] will be thrown.
  /// [execute] must be a function whose first parameter must be of type [MessageContext].
  Command.textOnly(
    String name,
    String description,
    Function execute, {
    List<String> aliases = const [],
    Iterable<GroupMixin> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    bool? hideOriginalResponse,
  }) : this._(
          name,
          description,
          execute,
          MessageContext,
          aliases: aliases,
          type: CommandType.textOnly,
          children: children,
          checks: checks,
          singleChecks: singleChecks,
          hideOriginalResponse: hideOriginalResponse,
        );

  /// Create a new slash-only [Command].
  ///
  /// [name] must match [commandNameRegexp] or an [CommandRegistrationError] will be thrown.
  /// [execute] must be a function whose first parameter must be of type [InteractionContext].
  Command.slashOnly(
    String name,
    String description,
    Function execute, {
    List<String> aliases = const [],
    Iterable<GroupMixin> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    bool? hideOriginalResponse,
  }) : this._(
          name,
          description,
          execute,
          InteractionContext,
          aliases: aliases,
          type: CommandType.slashOnly,
          children: children,
          checks: checks,
          singleChecks: singleChecks,
          hideOriginalResponse: hideOriginalResponse,
        );

  Command._(
    this.name,
    this.description,
    this.execute,
    Type contextType, {
    this.aliases = const [],
    this.type = CommandType.all,
    Iterable<GroupMixin> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    this.hideOriginalResponse,
  }) {
    if (!commandNameRegexp.hasMatch(name) || name != name.toLowerCase()) {
      throw CommandRegistrationError('Invalid command name "$name"');
    }

    _loadArguments(execute, contextType);

    for (final child in children) {
      addCommand(child);
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

    Iterable<ParameterMirror> arguments = _mirror.parameters;

    if (arguments.isEmpty) {
      throw CommandRegistrationError('Command callback function must have a Context parameter');
    }

    if (!reflectType(contextType).isAssignableTo(arguments.first.type)) {
      throw CommandRegistrationError(
          'The first parameter of a command callback must be of type $contextType');
    }

    // Skip context argument
    _arguments = arguments.skip(1);
    _requiredArguments = _arguments.fold(0, (i, e) {
      if (e.isOptional) {
        return i;
      }
      return i + 1;
    });

    for (final parametrer in _arguments) {
      if (!parametrer.type.hasReflectedType) {
        throw CommandRegistrationError('Command callback parameters must have reflected types');
      }
      if (parametrer.type.reflectedType == dynamic) {
        throw CommandRegistrationError('Command callback parameters must not be of type "dynamic"');
      }
      if (parametrer.isNamed) {
        throw CommandRegistrationError('Command callback parameters must not be named parameters');
      }
      if (parametrer.metadata.where((element) => element.reflectee is Description).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one Description annotation');
      }
      if (parametrer.metadata.where((element) => element.reflectee is Choices).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one Choices annotation');
      }
      if (parametrer.metadata.where((element) => element.reflectee is Name).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one Name annotation');
      }
      if (parametrer.metadata.where((element) => element.reflectee is UseConverter).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one UseConverter annotation');
      }
    }

    for (final argument in _arguments) {
      Iterable<Name> names = argument.metadata
          .where((element) => element.reflectee is Name)
          .map((nameMirror) => nameMirror.reflectee)
          .cast<Name>();

      String argumentName;
      if (names.isNotEmpty) {
        argumentName = names.first.name;

        if (!commandNameRegexp.hasMatch(argumentName) || name != name.toLowerCase()) {
          throw CommandRegistrationError('Invalid argument name "$argumentName"');
        }
      } else {
        String rawArgumentName = MirrorSystem.getName(argument.simpleName);

        argumentName = convertToKebabCase(rawArgumentName);

        if (!commandNameRegexp.hasMatch(argumentName) || name != name.toLowerCase()) {
          throw CommandRegistrationError(
              'Could not convert parameter "$rawArgumentName" to a valid Discord '
              'Slash command argument name (got "$argumentName")');
        }
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
        throw CommandRegistrationError(
            'Descriptions must not be empty nor longer than 100 characters');
      }

      Iterable<Choices> choices = argument.metadata
          .where((element) => element.reflectee is Choices)
          .map((choicesMirror) => choicesMirror.reflectee)
          .cast<Choices>();

      if (choices.isNotEmpty) {
        _mappedChoices[argumentName] = choices.first;
      }

      Iterable<UseConverter> converterOverrides = argument.metadata
          .where((element) => element.reflectee is UseConverter)
          .map((useConverterMirror) => useConverterMirror.reflectee)
          .cast<UseConverter>();

      if (converterOverrides.isNotEmpty) {
        UseConverter converterOverride = converterOverrides.first;

        if (!reflectType(converterOverride.converter.output).isAssignableTo(argument.type)) {
          throw CommandRegistrationError('Invalid converter override');
        }

        _mappedConverterOverrides[argumentName] = converterOverride;
      }

      _mappedDescriptions[argumentName] = description;
      _mappedArgumentTypes[argumentName] = argument.type.reflectedType;
      _mappedArgumentMirrors[argumentName] = argument;
      _orderedArgumentNames.add(argumentName);
    }
  }

  /// Parse arguments contained in the context and call [execute].
  ///
  /// If not enough arguments are provided, [NotEnoughArgumentsException] is thrown. Remaining
  /// data after all optional and non-optional arguments have been parsed is discarded.
  /// If an exception is thrown from [execute], it is caught and rethrown as an [UncaughtException].
  ///
  /// The arguments, if the context is a [MessageContext], will be parsed using the relevant
  /// converter on the [commands]. If no converter is found, the command execution will fail.
  ///
  /// If the context is an [InteractionContext], the arguments will either be parsed from their raw
  /// string representations or will not be parsed at all if the type received from the API is
  /// correct.
  Future<void> invoke(CommandsPlugin commands, Context context) async {
    List<Future<dynamic>> arguments = [];

    if (context is MessageContext) {
      StringView argumentsView = StringView(context.rawArguments);

      for (final argumentName in _orderedArgumentNames) {
        if (argumentsView.eof) {
          break;
        }

        Type expectedType = _mappedArgumentTypes[argumentName]!;

        arguments.add(parse(
          commands,
          context,
          argumentsView,
          expectedType,
          converterOverride: _mappedConverterOverrides[argumentName]?.converter,
        ));
      }

      if (arguments.length < _requiredArguments) {
        throw NotEnoughArgumentsException(context);
      }
    } else if (context is InteractionContext) {
      for (final argumentName in _orderedArgumentNames) {
        if (!context.rawArguments.containsKey(argumentName)) {
          arguments
              .add(Future.value(_mappedArgumentMirrors[argumentName]!.defaultValue?.reflectee));
          continue;
        }

        dynamic rawArgument = context.rawArguments[argumentName]!;
        Type expectedType = _mappedArgumentTypes[argumentName]!;

        if (reflect(rawArgument).type.isAssignableTo(reflectType(expectedType))) {
          arguments.add(Future.value(rawArgument));
          continue;
        }

        arguments.add(parse(
          commands,
          context,
          StringView(rawArgument.toString()),
          expectedType,
          converterOverride: _mappedConverterOverrides[argumentName]?.converter,
        ));
      }
    }

    context.arguments = await Future.wait(arguments);

    for (final check in [...checks, ...singleChecks]) {
      if (!await check.check(context)) {
        throw CheckFailedException(check, context);
      }
    }

    preCallController.add(context);

    try {
      await Function.apply(execute, [context, ...context.arguments]);
    } on Exception catch (e) {
      throw UncaughtException(e, context);
    }

    postCallController.add(context);
  }

  @override
  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands) {
    if (type != CommandType.textOnly) {
      List<CommandOptionBuilder> options = [];

      for (final mirror in _arguments) {
        Iterable<Name> names = mirror.metadata
            .where((element) => element.reflectee is Name)
            .map((nameMirror) => nameMirror.reflectee)
            .cast<Name>();

        String name;
        if (names.isNotEmpty) {
          name = names.first.name;
        } else {
          String rawArgumentName = MirrorSystem.getName(mirror.simpleName);

          name = convertToKebabCase(rawArgumentName);
        }

        Converter<dynamic>? argumentConverter = _mappedConverterOverrides[name]?.converter ??
            commands.getConverter(mirror.type.reflectedType);

        Iterable<ArgChoiceBuilder>? choices = _mappedChoices[name]?.builders;

        choices ??= argumentConverter?.choices;

        options.add(CommandOptionBuilder(
          argumentConverter?.type ?? CommandOptionType.string,
          name,
          _mappedDescriptions[name]!.value,
          required: !mirror.isOptional,
          choices: choices?.toList(),
        ));
      }

      return options;
    } else {
      // Text-only commands might have children which are slash commands
      return super.getOptions(commands);
    }
  }

  @override
  void addCommand(GroupMixin command) {
    if (type != CommandType.textOnly) {
      if (command.hasSlashCommand || (command is Command && command.type != CommandType.textOnly)) {
        throw CommandRegistrationError('Cannot nest Slash commands!');
      }
    }

    super.addCommand(command);
  }

  /// Add a check to this commands [singleChecks].
  void singleCheck(AbstractCheck check) {
    for (final preCallHook in check.preCallHooks) {
      onPreCall.listen(preCallHook);
    }

    for (final postCallHook in check.postCallHooks) {
      onPostCall.listen(postCallHook);
    }

    singleChecks.add(check);
  }

  @override
  String toString() => 'Command[name="$name", fullName="$fullName"]';
}
