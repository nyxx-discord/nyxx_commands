// ignore_for_file: public_member_api_docs

part of nyxx_commands;

class CommandsException implements Exception {
  String message;

  CommandsException(this.message);

  @override
  String toString() => 'Command Exception: $message';
}

class CommandInvocationException extends CommandsException {
  final Context context;

  CommandInvocationException(String message, this.context) : super(message);
}

class UncaughtException extends CommandInvocationException {
  final Exception exception;

  UncaughtException(this.exception, Context context) : super(exception.toString(), context);
}

class BadInputException extends CommandInvocationException {
  BadInputException(String message, Context context) : super(message, context);
}

class NotEnoughArgumentsException extends BadInputException {
  NotEnoughArgumentsException(MessageContext context)
      : super(
          'Not enough arguments for command "${context.command.fullName}": '
          '"${context.rawArguments}"',
          context,
        );
}

class CheckFailedException extends CommandInvocationException {
  final Check failed;

  CheckFailedException(this.failed, Context context)
      : super('Check "${failed.name}" failed', context);
}

class CommandNotFound extends CommandsException {
  final StringView input;

  CommandNotFound(this.input) : super('Command "${input.buffer}" not found');
}

class NoConverterException extends CommandInvocationException {
  final Type expectedType;

  NoConverterException(this.expectedType, Context context)
      : super('No converter found for type "$expectedType"', context);
}

class ParsingError implements Exception {
  final String message;

  ParsingError(this.message);

  @override
  String toString() => message;
}

class CommandsError extends Error {
  final String message;

  CommandsError(this.message);

  @override
  String toString() => message;
}

class CommandRegistrationError extends CommandsError {
  CommandRegistrationError(String message) : super(message);
}
