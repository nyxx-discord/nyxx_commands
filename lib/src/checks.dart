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
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'context.dart';

/// Represents a check executed on a [Command].
///
/// All checks must succeed in order for a [Command] to be executed.
abstract class AbstractCheck {
  /// The name of the check
  final String name;

  /// Create a new [AbstractCheck] with a given name.
  AbstractCheck(this.name);

  /// The method called to validate this check.
  ///
  /// Should not change the check's internal state.
  FutureOr<bool> check(Context context);

  /// An Iterable of permission overrides that will be used on slash commands using this check.
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions;

  /// An Iterable of pre-call hooks that will be called when a command this check is on emits to
  /// [Command.onPreCall].
  ///
  /// Should be used by checks that have internal state to update that state, instead of updating it
  /// in [check].
  Iterable<void Function(Context)> get preCallHooks;

  /// An Iterable of post-call hooks that will be called when a command this check is on emits to
  /// [Command.onPostCall].
  ///
  /// Should be used by checks that have internal state to update that state, instead of updating it
  /// in [check].
  Iterable<void Function(Context)> get postCallHooks;

  @override
  String toString() => 'Check[name=$name]';
}

/// Represents a simple stateless check.
class Check extends AbstractCheck {
  final FutureOr<bool> Function(Context) _check;

  /// Creates a new [Check].
  ///
  /// [check] should return a bool indicating whether this check succeeded.
  /// It should not throw.
  Check(this._check, [String name = 'Check']) : super(name);

  /// Creates a new [Check] that succeeds if at least one of the supplied checks succeed.
  factory Check.any(Iterable<AbstractCheck> checks, [String? name]) => _AnyCheck(checks, name);

  /// Creates a new [Check] that inverts the result of the supplied check. Use this to allow use of
  /// commands by default but deny it for certain users.
  factory Check.deny(AbstractCheck check, [String? name]) => _DenyCheck(check, name);

  /// Creates a new [Check] that succeeds if all of the supplied checks succeeds, and fails
  /// otherwise.
  ///
  /// This effectively functions the same as [GroupMixin.checks] and [Command.singleChecks], but can
  /// be used to group common patterns of checks together.
  ///
  /// Stateful checks in [checks] will share their state for all uses of this check group.
  factory Check.all(Iterable<AbstractCheck> checks, [String? name]) => _GroupCheck(checks, name);

  @override
  FutureOr<bool> check(Context context) => _check(context);

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value([]);

  @override
  Iterable<void Function(Context context)> get postCallHooks => [];

  @override
  Iterable<void Function(Context context)> get preCallHooks => [];
}

class _AnyCheck extends Check {
  Iterable<AbstractCheck> checks;

  _AnyCheck(this.checks, [String? name])
      : super((context) async {
          Iterable<FutureOr<bool>> results = checks.map((e) => e.check(context));

          Iterable<Future<bool>> asyncResults = results.whereType<Future<bool>>();
          Iterable<bool> syncResults = results.whereType<bool>();

          return syncResults.any((v) => v) || (await Future.wait(asyncResults)).any((v) => v);
        }, name ?? 'Any of [${checks.map((e) => e.name).join(', ')}]') {
    if (checks.isEmpty) {
      throw Exception('Cannot check any of no checks');
    }
  }

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions async {
    Iterable<Iterable<CommandPermissionBuilderAbstract>> permissions =
        await Future.wait(checks.map((check) => check.permissions));

    return permissions.first.where(
      (permission) =>
          permission.hasPermission ||
          // If permission is not granted, we check that it is not allowed by any of the other
          // checks. If every check denies the permission for this id, also deny the permission in
          // the combined version.
          permissions.every((element) => element.any(
                // CommandPermissionBuilderAbstract does not override == so we manually check it
                (p) => p.id == permission.id && !p.hasPermission,
              )),
    );
  }
}

class _DenyCheck extends Check {
  final AbstractCheck source;

  _DenyCheck(this.source, [String? name])
      : super((context) async => !(await source.check(context)), name ?? 'Denied ${source.name}');

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions async {
    Iterable<CommandPermissionBuilderAbstract> permissions = await source.permissions;

    Iterable<RoleCommandPermissionBuilder> rolePermissions =
        permissions.whereType<RoleCommandPermissionBuilder>();

    Iterable<UserCommandPermissionBuilder> userPermissions =
        permissions.whereType<UserCommandPermissionBuilder>();

    return [
      ...rolePermissions.map((permission) => CommandPermissionBuilderAbstract.role(permission.id,
          hasPermission: !permission.hasPermission)),
      ...userPermissions
          .map((e) => CommandPermissionBuilderAbstract.user(e.id, hasPermission: !e.hasPermission)),
    ];
  }
}

class _GroupCheck extends Check {
  final Iterable<AbstractCheck> checks;

  _GroupCheck(this.checks, [String? name])
      : super((context) async {
          Iterable<FutureOr<bool>> results = checks.map((e) => e.check(context));

          Iterable<Future<bool>> asyncResults = results.whereType<Future<bool>>();
          Iterable<bool> syncResults = results.whereType<bool>();

          return !syncResults.contains(false) && !(await Future.wait(asyncResults)).contains(false);
        }, name ?? 'All of [${checks.map((e) => e.name).join(', ')}]');

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions async =>
      (await Future.wait(checks.map(
        (e) => e.permissions,
      )))
          .fold([],
              (acc, element) => (acc as List<CommandPermissionBuilderAbstract>)..addAll(element));
}

/// A [Check] thats checks for a specific role or roles.
///
/// Integrates with Discord slash command permissions:
/// - Denies use by default
/// - Allows use for the specified role(s)
class RoleCheck extends Check {
  /// The roles this check allows.
  Iterable<Snowflake> roleIds;

  /// Create a new Role Check based on a role.
  RoleCheck(IRole role, [String? name]) : this.id(role.id, name);

  /// Create a new Role Check based on a role id.
  RoleCheck.id(Snowflake id, [String? name])
      : roleIds = [id],
        super(
          (context) => context.member?.roles.any((role) => role.id == id) ?? false,
          name ?? 'Role Check on $id',
        );

  /// Create a new Role Check based on multiple roles.
  RoleCheck.any(Iterable<IRole> roles, [String? name])
      : this.anyId(roles.map((role) => role.id), name);

  /// Create a new Role Check based on multiple role ids.
  RoleCheck.anyId(Iterable<Snowflake> roles, [String? name])
      : roleIds = roles,
        super(
          (context) => context.member?.roles.any((role) => roles.contains(role.id)) ?? false,
          name ?? 'Role Check on any of [${roles.join(', ')}]',
        );

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value([
        CommandPermissionBuilderAbstract.role(Snowflake.zero(), hasPermission: false),
        ...roleIds.map((e) => CommandPermissionBuilderAbstract.role(e, hasPermission: true)),
      ]);
}

/// A [Check] that checks for a specific user or users.
///
/// Integrates with Discord slash command permissions:
/// - Denies use by default
/// - Allows use for the specified user(s)
class UserCheck extends Check {
  /// The users this check allows.
  Iterable<Snowflake> userIds;

  /// Create a User Check based on a user.
  UserCheck(IUser user, [String? name]) : this.id(user.id, name);

  /// Create a User Check based on a user id.
  UserCheck.id(Snowflake id, [String? name])
      : userIds = [id],
        super((context) => context.user.id == id, name ?? 'User Check on $id');

  /// Create a User Check based on multiple users.
  UserCheck.any(Iterable<IUser> users, [String? name])
      : this.anyId(users.map((user) => user.id), name);

  /// Create a User Check based on multiple user ids.
  UserCheck.anyId(Iterable<Snowflake> ids, [String? name])
      : userIds = ids,
        super(
          (context) => ids.contains(context.user.id),
          name ?? 'User Check on any of [${ids.join(', ')}]',
        );

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value([
        CommandPermissionBuilderAbstract.user(Snowflake.zero(), hasPermission: false),
        ...userIds.map((e) => CommandPermissionBuilderAbstract.user(e, hasPermission: true)),
      ]);
}

/// A [Check] that checks for a specific guild.
///
/// This check is treated specially by [CommandsPlugin]:
/// - There can only be one [GuildCheck] per command
/// - Commands will be registered as guild commands in the specified guilds. This overrides
/// [CommandsPlugin.guild]
class GuildCheck extends Check {
  /// The guilds this check allows.
  ///
  /// `null` indicates that all guilds are allowed.
  Iterable<Snowflake?> guildIds;

  /// Create a Guild Check based on a guild.
  GuildCheck(IGuild guild, [String? name]) : this.id(guild.id, name);

  /// Create a Guild Check based on a guild id.
  GuildCheck.id(Snowflake id, [String? name])
      : guildIds = [id],
        super((context) => context.guild?.id == id, name ?? 'Guild Check on $id');

  /// Create a Guild Check that allows no guilds.
  ///
  /// This means that this command can only be executed as a text command in DMs with the bot.
  GuildCheck.none([String? name])
      : guildIds = [],
        super((context) => context.guild == null, name ?? 'Guild Check on <none>');

  /// Create a Guild Check that allows all guilds, but denies DMs.
  ///
  /// This means that this command will be registered globally or, if it is set, the guild specified
  /// by [CommandsPlugin.guild], and cannot be used in DMs with the bot.
  GuildCheck.all([String? name])
      : guildIds = [null],
        super(
          (context) => context.guild != null,
          name ?? 'Guild Check on <any>',
        );

  /// Create a Guild Check based on multiple guilds.
  GuildCheck.any(Iterable<IGuild> guilds, [String? name])
      : this.anyId(guilds.map((guild) => guild.id), name);

  /// Create a Guild Check based on multiple guild ids.
  GuildCheck.anyId(Iterable<Snowflake> ids, [String? name])
      : guildIds = ids,
        super(
          (context) => ids.contains(context.guild?.id),
          name ?? 'Guild Check on any of [${ids.join(', ')}]',
        );
}

/// Represents different types of cooldown
enum CooldownType {
  /// Cooldown is per category.
  ///
  /// If the command is executed in a guild channel belonging to a category, the cooldown is set for
  /// all users in all channels belonging to that category.
  ///
  /// If the channel does not belong to a category or is not a guild channel, the cooldown works in
  /// the same way as [channel].
  category,

  /// Cooldown is per channel.
  ///
  /// If the command is executed in a channel, then the cooldown is set for all users in that
  /// channel.
  channel,

  /// Cooldown is per command.
  ///
  /// If the command is executed, then the cooldown is set for all users in all channels for that
  /// command.
  command,

  /// Cooldown is global.
  ///
  /// Generally works in the same was as [command], but if the same [CooldownCheck] instance is used
  /// in multiple commands' [GroupMixin.checks] or [Command.singleChecks] then the cooldown will be
  /// set for all users in all channels for the commands sharing the [CooldownCheck] instance.
  global,

  /// Cooldown is per guild.
  ///
  /// If the command is executed in a guild, then the cooldown is set for all users in all channels
  /// in that guild. If the command is executed outside of a guild, then the cooldown works in the
  /// same way as [channel].
  guild,

  /// Cooldown is per role.
  ///
  /// If the command is executed in a guild by a member, then the command is set for all channels
  /// for all members with the same highest role as the member. If the command is executed by a
  /// member with no roles, the cooldown is set for all members with no roles. If the command is
  /// executed outside of a guild, the cooldown works in the same way as [channel].
  role,

  /// Cooldown is per user.
  ///
  /// If the command is executed by a user, then the cooldown is set for all channels for that user.
  user,
}

class _BucketEntry {
  final DateTime start;
  int count = 1;

  _BucketEntry(this.start);
}

/// A [Check] that checks that a [Command] is not on cooldown.
class CooldownCheck extends AbstractCheck {
  // Implementation of a cooldown system that does not store last-used times forever, does not use
  // [Timer]s and does not perform a filtering pass on the entire data set.
  //
  // Works by storing last-used time temporarily in two maps. The first stores last-used times in
  // a period equivalent to the cooldown time and the second stores last-used times in the previous
  // period.
  // If a key is present in the current map, then the cooldown will certainly be active for that key
  // (if the token usage is high enough). If a key is in the previous map, then it might still be
  // active but needs additional checking. If a key is not in the current nor in the previous
  // period, then it is certainly not active, meaning that only last-used times for the current and
  // previous periods need to be stored.

  /// Create a new [CooldownCheck] with a specific type, period and token count.
  CooldownCheck(this.type, this.duration, [this.tokensPer = 1, String? name])
      : super(name ?? 'Cooldown Check on $type');

  /// The number of tokens per [duration].
  ///
  /// A command can be executed [tokensPer] times each [duration] before this check fails. The
  /// cooldown starts as soon as the first token is consumed, not when the last token is consumed.
  int tokensPer;

  /// The duration of this cooldown.
  Duration duration;

  /// The type of this cooldown.
  ///
  /// See [CooldownType] for details on how each type is handled.
  final CooldownType type;

  Map<int, _BucketEntry> _currentBucket = {};
  Map<int, _BucketEntry> _previousBucket = {};

  late DateTime _currentStart = DateTime.now();

  @override
  FutureOr<bool> check(Context context) {
    if (DateTime.now().isAfter(_currentStart.add(duration))) {
      _previousBucket = _currentBucket;
      _currentBucket = {};

      _currentStart = DateTime.now();
    }

    int key = getKey(context);

    if (_currentBucket.containsKey(key)) {
      return _currentBucket[key]!.count < tokensPer;
    }

    if (_previousBucket.containsKey(key)) {
      return !_isActive(_previousBucket[key]!) || _previousBucket[key]!.count < tokensPer;
    }

    return true;
  }

  bool _isActive(_BucketEntry entry) => entry.start.add(duration).isAfter(DateTime.now());

  /// Get a key representing a [Context] depending on [type].
  int getKey(Context context) {
    switch (type) {
      case CooldownType.category:
        if (context.guild != null) {
          if ((context.channel as IGuildChannel).parentChannel != null) {
            return (context.channel as IGuildChannel).parentChannel!.id.id;
          }
        }
        return context.channel.id.id;
      case CooldownType.channel:
        return context.channel.id.id;
      case CooldownType.command:
        return context.command.hashCode;
      case CooldownType.global:
        return 0;
      case CooldownType.guild:
        return context.guild?.id.id ?? context.user.id.id;
      case CooldownType.role:
        if (context.member != null) {
          if (context.member!.roles.isNotEmpty) {
            return PermissionsUtils.getMemberHighestRole(context.member!).id.id;
          }
          return context.guild!.everyoneRole.id.id;
        }
        return context.channel.id.id;
      case CooldownType.user:
        return context.user.id.id;
    }
  }

  @override
  late Iterable<void Function(Context)> preCallHooks = [
    (context) {
      int key = getKey(context);

      if (_previousBucket.containsKey(key) && _isActive(_previousBucket[key]!)) {
        _previousBucket[key]!.count++;
      } else if (_currentBucket.containsKey(key)) {
        _currentBucket[key]!.count++;
      } else {
        _currentBucket[key] = _BucketEntry(DateTime.now());
      }
    }
  ];

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value([]);

  @override
  Iterable<void Function(Context p1)> get postCallHooks => [];
}

/// A [Check] that checks that a [Command] is invoked from an [InteractionEvent].
///
/// If you just want to restrict command usage to slash commands, use [Command.slashOnly] instead.
/// This class is meant to be used with [Check.any] and other checks to allow interaction commands
/// to bypass checks.
class InteractionCheck extends Check {
  /// Create a new [InteractionCheck]
  InteractionCheck([String? name])
      : super((context) => context is InteractionContext, name ?? 'Interaction Check');
}

/// A [Check] that checks that a [Command] is invoked from a text message.
///
/// If you want to restrict command usage to text-only, use [Command.textOnly] instead. This class
/// is meant to be used with [Check.any] and other checks to allow text commands to bypass checks.
///
/// Integrates with Discord slash command permissions (denies usage entirely).
class MessageCheck extends Check {
  /// Create a new [MessageCheck]
  MessageCheck([String? name])
      : super((context) => context is MessageContext, name ?? 'Message Check');

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value(
        [CommandPermissionBuilderAbstract.role(Snowflake.zero(), hasPermission: false)],
      );
}
