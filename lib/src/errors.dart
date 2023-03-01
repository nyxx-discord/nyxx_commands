import 'package:runtime_type/runtime_type.dart';

import 'checks/checks.dart';
import 'context/autocomplete_context.dart';
import 'context/base.dart';
import 'context/chat_context.dart';
import 'context/component_context.dart';
import 'converters/converter.dart';
import 'util/util.dart';
import 'util/view.dart';

/// The base class for exceptions thrown by nyxx_commands.
///
/// All exceptions thrown by the library extend or implement this class, so you may use this as a
/// catch-all type. Exceptions thrown by nyxx_commands are often caught internally by the library
/// and added to [CommandsPlugin.onCommandError], so you need not catch exceptions yourself.
///
/// You might also be interested in:
/// - [CommandsError], the base class for all errors thrown by nyxx_commands;
/// - [CommandsPlugin.onCommandError], for handling exceptions thrown in commands.
class CommandsException implements Exception {
  /// The message for this exception.
  ///
  /// This might contain sensitive information, so it is not recommended to send this string to your
  /// users. Checking the type of the error and reacting accordingly is recommended.
  String message;

  /// The stack trace at the point where this exception was first thrown.
  ///
  /// Might be unset if nyxx_commands has not yet handled this exception. The `stackTrace = ...`
  /// setter should not be called if this is already non-null, so you should avoid calling it unless
  /// you are creating exceptions yourself.
  StackTrace? get stackTrace => _stackTrace;

  set stackTrace(StackTrace? stackTrace) {
    if (this.stackTrace != null) {
      // Use a native error instead of one from nyxx_commands that could potentially lead to an
      // infinite error loop
      throw StateError('Cannot set CommandsException.stackTrace if it is already set');
    }

    _stackTrace = stackTrace;
  }

  StackTrace? _stackTrace;

  /// Create a new [CommandsException].
  CommandsException(this.message);

  @override
  String toString() => 'Command Exception: $message';
}

/// An exception that can be attached to a known context.
///
/// Subclasses of this exception are generally thrown during the processing of [context].
class ContextualException extends CommandsException {
  /// The context in which the exception occurred.
  final IContextData context;

  /// Create a new [ContextualException].
  ContextualException(super.message, this.context);
}

/// An exception thrown when an interaction on a component created by nyxx_commands was received but
/// was not handled.
class UnhandledInteractionException extends CommandsException implements ContextualException {
  @override
  final IComponentContext context;

  /// The [ComponentId] of the component that was interacted with.
  final ComponentId componentId;

  /// The reason this interaction was not handled.
  ComponentIdStatus get reason => componentId.status;

  /// Create a new [UnhandledInteractionException].
  UnhandledInteractionException(this.context, this.componentId)
      : super('Unhandled interaction: ${componentId.status}');
}

/// An exception that occurred during the execution of a command.
class CommandInvocationException extends CommandsException implements ContextualException {
  @override
  final ICommandContext context;

  /// Create a new [CommandInvocationException].
  CommandInvocationException(super.message, this.context);
}

/// A wrapper class for an exception that caused an autocomplete event to fail.
///
/// This generally indicates incorrect or slow code inside an autocomplete callback, and the
/// developer should try to fix the issue.
///
/// If you are throwing exceptions to indicate autocomplete failure, consider returning `null`
/// instead.
class AutocompleteFailedException extends CommandsException {
  /// The context in which the exception occurred.
  ///
  /// If the exception was not triggered by a slow response, default options can still be returned
  /// by accessing the [AutocompleteContext.interactionEvent] and calling
  /// [IAutocompleteInteractionEvent.respond] with the default options.
  final AutocompleteContext context;

  /// The exception that occurred.
  final Exception exception;

  /// Create a new [AutocompleteFailedException].
  AutocompleteFailedException(this.exception, this.context) : super(exception.toString());
}

/// A wrapper class for an exception that was thrown inside the [ICommand.execute] callback.
///
/// This generally indicates incorrect or incomplete code inside a command callback, and the
/// developer should try to identify and fix the issue.
///
/// If you are throwing exceptions to indicate command failure, consider using [Check]s instead.
class UncaughtException extends CommandInvocationException {
  /// The exception that occurred.
  final Object exception;

  /// Create a new [UncaughtException].
  UncaughtException(this.exception, ICommandContext context) : super(exception.toString(), context);
}

/// An exception thrown when an interaction times out in a command.
///
/// This is the exception thrown by [IInteractiveContext.getButtonPress],
/// [IInteractiveContext.getSelection] and other methods that might time out.
class InteractionTimeoutException extends CommandInvocationException {
  /// Create a new [InteractionTimeouException].
  InteractionTimeoutException(super.message, super.context);
}

/// An exception thrown by nyxx_commands to indicate misuse of the library.
class UncaughtCommandsException extends UncaughtException {
  @override
  final StackTrace stackTrace;

  /// Create a new [UncaughtCommandsException].
  UncaughtCommandsException(String message, ICommandContext context)
      : stackTrace = StackTrace.current,
        super(CommandsException(message), context);
}

/// An exception that occurred due to an invalid input from the user.
///
/// This generally indicates that nyxx_commands was unable to parse the user's input.
class BadInputException extends ContextualException {
  /// Create a new [BadInputException].
  BadInputException(super.message, super.context);
}

/// An exception thrown when a converter fails to convert user input.
class ConverterFailedException extends BadInputException {
  /// The converter that failed.
  final Converter<dynamic> failed;

  /// The [StringView] representing the arguments before the converter was invoked.
  final StringView input;

  /// Create a new [ConverterFailedException].
  ConverterFailedException(this.failed, this.input, IContextData context)
      : super(
          'Could not parse input $input to type "${failed.type}"',
          context,
        );
}

/// An exception thrown when the end of user input is encountered before all the required arguments
/// of a [ChatCommand] have been parsed.
class NotEnoughArgumentsException extends CommandInvocationException implements BadInputException {
  /// Create a new [NotEnoughArgumentsException].
  NotEnoughArgumentsException(MessageChatContext context)
      : super(
          'Not enough arguments for command "${context.command.fullName}": '
          '"${context.rawArguments}"',
          context,
        );
}

/// An exception thrown when an [AbstractCheck] fails.
class CheckFailedException extends CommandInvocationException {
  /// The check that failed.
  final AbstractCheck failed;

  /// Create a new [CheckFailedException].
  CheckFailedException(this.failed, ICommandContext context)
      : super('Check "${failed.name}" failed', context);
}

/// An exception thrown when no [Converter] was found or created for a type.
///
/// You might also be interested in:
/// - [CommandsPlugin.addConverter], for adding your own [Converter]s to your bot.
class NoConverterException extends CommandsException {
  /// The type that the converter was requested for.
  final RuntimeType<dynamic> expectedType;

  /// Create a new [NoConverterException].
  NoConverterException(this.expectedType) : super('No converter found for type "$expectedType"');
}

/// An exception thrown when a message command matching [CommandsPlugin.prefix] is found, but no
/// command could be resolved from the rest of the message.
///
/// This exception can safely be ignored.
class CommandNotFoundException extends CommandsException {
  /// The text input that was received.
  final StringView input;

  /// Create a new [CommandNotFoundException].
  CommandNotFoundException(this.input) : super('Command "${input.buffer}" not found');
}

/// An exception that occurred while a [StringView] was parsing input.
///
/// When parsing user input, this will automatically be caught and wrapped in a [BadInputException].
class ParsingException implements Exception {
  /// The error message.
  final String message;

  /// Create a new [ParsingException].
  ParsingException(this.message);

  @override
  String toString() => message;
}

/// The base class for all errors thrown by nyxx_commands.
///
/// You might also be interested in:
/// - [CommandsException], the base class for all exceptions thrown by nyxx_commands.
class CommandsError extends Error {
  /// The message for this error.
  final String message;

  /// Create a new [CommandsError].
  CommandsError(this.message);

  @override
  String toString() => message;
}

/// An error that occurred during registration of a command.
class CommandRegistrationError extends CommandsError {
  /// Create a new [CommandRegistrationError].
  CommandRegistrationError(super.message);
}
