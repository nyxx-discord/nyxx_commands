/// A framework for easily creating slash commands and text commands for Discord using the
/// [nyxx](https://pub.dev/packages/nyxx) library.
library nyxx_commands;

import 'dart:async';
import 'dart:mirrors';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/interactions.dart';

part 'src/bot.dart';
part 'src/command.dart';
part 'src/context.dart';
part 'src/converter.dart';
part 'src/errors.dart';
part 'src/group.dart';
part 'src/util.dart';
part 'src/view.dart';
