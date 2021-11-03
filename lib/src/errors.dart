// ignore_for_file: public_member_api_docs

part of nyxx_commands;

class CommandsException implements Exception {
  String? message;

  CommandsException([this.message]);

  @override
  String toString() {
    return message == null ? 'Command Exception' : 'Command Exception: $message';
  }
}

class SlashException extends CommandsException {
  SlashException(String message) : super(message);
}

class CommandNotFound extends CommandsException {
  CommandNotFound(String name) : super('Command "$name" not found.');
}

class CommandInvokeException extends CommandsException {
  CommandInvokeException(String message) : super(message);
}

class NotEnoughArgumentsException extends CommandInvokeException {
  NotEnoughArgumentsException(int got, int expected)
      : super('Not enough arguments: expected $expected, got $got');
}

class BadInputException extends CommandInvokeException {
  BadInputException({
    Type? type,
    String message = '',
  }) : super(
          type == null ? message : 'Invalid format for argument type "$type"',
        );
}

class MissingConverterException extends CommandInvokeException {
  MissingConverterException(Type type)
      : super(
          'Missing converter for type "$type"',
        );
}

class UncaughtException extends CommandInvokeException {
  UncaughtException(Exception exc)
      : super(
          'Uncaught exception in command: ${exc.toString()}',
        );
}

class CheckFailedException extends CommandInvokeException {
  CheckFailedException(Context context) : super('Check failed on context $context');
}

class ParsingException extends CommandsException {
  ParsingException([String? message]) : super(message);
}

class CommandRegistrationException extends CommandsException {
  CommandRegistrationException([String? message]) : super(message);
}

class DuplicateNameException extends CommandRegistrationException {
  DuplicateNameException(String name)
      : super(
          'Command with name or alias $name already exists',
        );
}

class AlreadyRegisteredException extends CommandRegistrationException {
  AlreadyRegisteredException(String name) : super('Command "$name" already has a parent');
}

class InvalidNameException extends CommandRegistrationException {
  InvalidNameException(String message) : super(message);
}

class InvalidFunctionException extends CommandRegistrationException {
  InvalidFunctionException(String message) : super(message);
}

class InvalidDescriptionException extends CommandRegistrationException {
  InvalidDescriptionException(String description) : super('Invalid description "$description"');
}

class InvalidPrefixException extends CommandsException {
  InvalidPrefixException(String message) : super(message);
}
