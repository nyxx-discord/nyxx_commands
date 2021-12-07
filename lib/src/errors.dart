part of nyxx_commands;

/// Base class for exceptions thrown by this library.
///
/// All exceptions thrown by this library extend this class, apart from [ParsingException].
class CommandsException implements Exception {
  /// A message attached to this exception.
  String message;

  /// Create a new [CommandsException] with a specific message.
  CommandsException(this.message);

  @override
  String toString() => 'Command Exception: $message';
}

/// Base class for exceptions thrown during command invocation.
class CommandInvocationException extends CommandsException {
  /// The context in which the exception occurred.
  final Context context;

  /// Create a new [CommandInvocationException] with a specific message and context.
  CommandInvocationException(String message, this.context) : super(message);
}

/// Exception thrown when an uncaught [Exception] is thrown by a command callback.
///
/// [Error]s and thrown [Object]s other than [Exception]s are not caught.
class UncaughtException extends CommandInvocationException {
  /// The thrown exception.
  final Exception exception;

  /// Create a new [UncaughtException] with a specific exception and context.
  UncaughtException(this.exception, Context context) : super(exception.toString(), context);
}

/// Base class for exceptions thrown during argument parsing.
///
/// A raw [BadInputException] is thrown when a [Converter] fails to parse an argument.
class BadInputException extends CommandInvocationException {
  /// Create a new [BadInputException] with a specific message and context.
  BadInputException(String message, Context context) : super(message, context);
}

/// Exception thrown when a command is invoked without the minimum amount of arguments required.
class NotEnoughArgumentsException extends BadInputException {
  /// Create a new [NotEnoughArgumentsException] with a specific context.
  NotEnoughArgumentsException(MessageContext context)
      : super(
          'Not enough arguments for command "${context.command.fullName}": '
          '"${context.rawArguments}"',
          context,
        );
}

/// Exception thrown when a [Check] fails.
class CheckFailedException extends CommandInvocationException {
  /// The [Check] that failed.
  final Check failed;

  /// Create a new [CheckFailedException] with a specific check and context.
  CheckFailedException(this.failed, Context context)
      : super('Check "${failed.name}" failed', context);
}

/// Exception thrown when no converter is found for a command argument.
class NoConverterException extends CommandInvocationException {
  /// The type of the argument.
  final Type expectedType;

  /// Create a new [NoConverterException] with a specific expected type and context.
  NoConverterException(this.expectedType, Context context)
      : super('No converter found for type "$expectedType"', context);
}

/// Exception thrown when an unrecognised command is received.
class CommandNotFoundException extends CommandsException {
  /// The received input.
  final StringView input;

  /// Create a new [CommandNotFoundException] with a specific input.
  CommandNotFoundException(this.input) : super('Command "${input.buffer}" not found');
}

/// Exception thrown by [StringView] when an invalid input is found.
///
/// If this is thrown inside a [Converter], it will be wrapped as a [BadInputException].
class ParsingException implements Exception {
  /// A message attached to this exception.
  final String message;

  /// Create a new [ParsingException] with a specific message.
  ParsingException(this.message);

  @override
  String toString() => message;
}

/// Base class for all errors thrown by this library.
class CommandsError extends Error {
  /// A message attached to this error.
  final String message;

  /// Create a new [CommandsError] with a specific message.
  CommandsError(this.message);

  @override
  String toString() => message;
}

/// Error thrown when an invalid command or command structure is registered.
class CommandRegistrationError extends CommandsError {
  /// Create a new [CommandRegistrationError] with a specific message.
  CommandRegistrationError(String message) : super(message);
}
