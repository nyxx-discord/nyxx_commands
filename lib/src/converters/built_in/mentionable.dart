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

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../converter.dart';
import '../fallback.dart';
import 'member.dart';
import 'role.dart';

/// A converter that converts input to a [Mentionable].
///
/// This will first attempt to convert the input as a member, then as a role.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.mentionable].
const Converter<Mentionable> mentionableConverter = FallbackConverter(
  [
    memberConverter,
    roleConverter,
  ],
  type: CommandOptionType.mentionable,
);
