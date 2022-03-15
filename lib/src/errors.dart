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

import 'checks/checks.dart';
import 'context/chat_context.dart';
import 'context/context.dart';
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

  /// Create a new [CommandsException].
  CommandsException(this.message);

  @override
  String toString() => 'Command Exception: $message';
}

/// An exception that occurred during the execution of a command.
class CommandInvocationException extends CommandsException {
  /// The context in which the exception occurred.
  final IContext context;

  /// Create a new [CommandInvocationException].
  CommandInvocationException(String message, this.context) : super(message);
}

/// A wrapper class for an exception that was thrown inside the [ICommand.execute] callback.
///
/// This generally indicates incorrect or incomplete code inside a command callback, and the
/// developer should try to identify and fix the issue.
///
/// If you are throwing exceptions to indicate command failure, consider using [Check]s instead.
class UncaughtException extends CommandInvocationException {
  /// The exception that occurred.
  final Exception exception;

  /// Create a new [UncaughtException].
  UncaughtException(this.exception, IContext context) : super(exception.toString(), context);
}

/// An exception that occurred due to an invalid input from the user.
///
/// This generally indicates that nyxx_commands was unable to parse the user's input.
class BadInputException extends CommandInvocationException {
  /// Create a new [BadInputException].
  BadInputException(String message, IChatContext context) : super(message, context);
}

/// An exception thrown when the end of userr input is encountered before all the required arguments
/// of a [ChatCommand] have been parsed.
class NotEnoughArgumentsException extends BadInputException {
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
  CheckFailedException(this.failed, IContext context)
      : super('Check "${failed.name}" failed', context);
}

/// An exception thrown when no [Converter] was found or created for a type.
///
/// You might also be interested in:
/// - [CommandsPlugin.addConverter], for adding your own [Converter]s to your bot.
class NoConverterException extends CommandInvocationException {
  /// The type that the converter was requested for.
  final Type expectedType;

  /// Create a new [NoConverterException].
  NoConverterException(this.expectedType, IChatContext context)
      : super('No converter found for type "$expectedType"', context);
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
  CommandRegistrationError(String message) : super(message);
}
