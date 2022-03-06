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

import 'package:nyxx_commands/src/context/context.dart';

import 'checks/checks.dart';
import 'context/chat_context.dart';
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

class BadInputException extends CommandInvocationException {
  BadInputException(String message, IChatContext context) : super(message, context);
}

class NotEnoughArgumentsException extends BadInputException {
  NotEnoughArgumentsException(MessageChatContext context)
      : super(
          'Not enough arguments for command "${context.command.fullName}": '
          '"${context.rawArguments}"',
          context,
        );
}

class CheckFailedException extends CommandInvocationException {
  final AbstractCheck failed;

  CheckFailedException(this.failed, IContext context)
      : super('Check "${failed.name}" failed', context);
}

class NoConverterException extends CommandInvocationException {
  final Type expectedType;

  NoConverterException(this.expectedType, IChatContext context)
      : super('No converter found for type "$expectedType"', context);
}

class CommandNotFoundException extends CommandsException {
  final StringView input;

  CommandNotFoundException(this.input) : super('Command "${input.buffer}" not found');
}

class ParsingException implements Exception {
  final String message;

  ParsingException(this.message);

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
