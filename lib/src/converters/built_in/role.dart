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

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'snowflake.dart';

FutureOr<IRole?> snowflakeToRole(Snowflake snowflake, IContextData context) {
  if (context.guild != null) {
    IRole? cached = context.guild!.roles[snowflake];
    if (cached != null) {
      return cached;
    }

    try {
      return context.guild!.fetchRoles().firstWhere((role) => role.id == snowflake);
    } on StateError {
      return null;
    }
  }

  return null;
}

FutureOr<IRole?> convertRole(StringView view, IContextData context) async {
  String word = view.getQuotedWord();
  if (context.guild != null) {
    Stream<IRole> roles = context.guild!.fetchRoles();

    List<IRole> exact = [];
    List<IRole> caseInsensitive = [];
    List<IRole> partial = [];

    await for (final role in roles) {
      if (role.name == word) {
        exact.add(role);
      }
      if (role.name.toLowerCase() == word.toLowerCase()) {
        caseInsensitive.add(role);
      }
      if (role.name.toLowerCase().startsWith(word.toLowerCase())) {
        partial.add(role);
      }
    }

    for (final list in [exact, caseInsensitive, partial]) {
      if (list.length == 1) {
        return list.first;
      }
    }
  }
  return null;
}

MultiselectOptionBuilder roleToMultiselectOption(IRole role) {
  MultiselectOptionBuilder builder = MultiselectOptionBuilder(
    role.name,
    role.id.toString(),
  );

  if (role.iconEmoji != null) {
    builder.emoji = UnicodeEmoji(role.iconEmoji!);
  }

  return builder;
}

ButtonBuilder roleToButton(IRole role) => ButtonBuilder(
      role.name,
      '',
      ButtonStyle.primary,
    );

/// A converter that converts input to an [IRole].
///
/// This will first attempt to parse the input as a snowflake that will then be converted to an
/// [IRole]. If this fails, then the role will be looked up by name in the current guild.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.role].
const Converter<IRole> roleConverter = FallbackConverter<IRole>(
  [
    CombineConverter<Snowflake, IRole>(snowflakeConverter, snowflakeToRole),
    Converter<IRole>(convertRole),
  ],
  type: CommandOptionType.role,
  toMultiselectOption: roleToMultiselectOption,
  toButton: roleToButton,
);
