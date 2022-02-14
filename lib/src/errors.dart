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

class CommandsException implements Exception {
  String message;

  CommandsException(this.message);

  @override
  String toString() => 'Command Exception: $message';
}

class CommandInvocationException extends CommandsException {
  final IContext context;

  CommandInvocationException(String message, this.context) : super(message);
}

class UncaughtException extends CommandInvocationException {
  final Exception exception;

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
