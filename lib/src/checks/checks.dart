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
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

abstract class AbstractCheck {
  final String name;

  AbstractCheck(this.name);

  FutureOr<bool> check(IContext context);

  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions;

  Iterable<void Function(IContext)> get preCallHooks;

  Iterable<void Function(IContext)> get postCallHooks;

  @override
  String toString() => 'Check[name=$name]';
}

class Check extends AbstractCheck {
  final FutureOr<bool> Function(IContext) _check;

  Check(this._check, [String name = 'Check']) : super(name);

  static AbstractCheck any(Iterable<AbstractCheck> checks, [String? name]) =>
      _AnyCheck(checks, name);

  static AbstractCheck deny(AbstractCheck check, [String? name]) => _DenyCheck(check, name);

  static AbstractCheck all(Iterable<AbstractCheck> checks, [String? name]) =>
      _GroupCheck(checks, name);

  @override
  FutureOr<bool> check(IContext context) => _check(context);

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value([]);

  @override
  Iterable<void Function(IContext context)> get postCallHooks => [];

  @override
  Iterable<void Function(IContext context)> get preCallHooks => [];
}

class _AnyCheck extends AbstractCheck {
  Iterable<AbstractCheck> checks;

  final Expando<AbstractCheck> _succesfulChecks = Expando();

  _AnyCheck(this.checks, [String? name])
      : super(name ?? 'Any of [${checks.map((e) => e.name).join(', ')}]') {
    if (checks.isEmpty) {
      throw Exception('Cannot check any of no checks');
    }
  }

  @override
  FutureOr<bool> check(IContext context) async {
    for (final check in checks) {
      FutureOr<bool> result = check.check(context);

      if (result is bool && result) {
        _succesfulChecks[context] = check;
        return true;
      } else if (await result) {
        _succesfulChecks[context] = check;
        return true;
      }
    }
    return false;
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

  @override
  Iterable<void Function(IContext)> get preCallHooks => [
        (context) {
          AbstractCheck? actualCheck = _succesfulChecks[context];

          if (actualCheck == null) {
            logger.warning("Context $context shouldn't have passed checks; actualCheck is null");
            return;
          }

          for (final hook in actualCheck.preCallHooks) {
            hook(context);
          }
        }
      ];

  @override
  Iterable<void Function(IContext)> get postCallHooks => [
        (context) {
          AbstractCheck? actualCheck = _succesfulChecks[context];

          if (actualCheck == null) {
            logger.warning("Context $context shouldn't have passed checks; actualCheck is null");
            return;
          }

          for (final hook in actualCheck.postCallHooks) {
            hook(context);
          }
        }
      ];
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

  // It may seem counterintuitive to call the success hooks if the source check failed, and this is
  // a situation where there is no proper solution. Here, we assume that the source check will
  // reset its state on failure after failure, so calling the hooks is desireable.
  @override
  Iterable<void Function(IContext)> get preCallHooks => source.preCallHooks;

  @override
  Iterable<void Function(IContext)> get postCallHooks => source.postCallHooks;
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

  @override
  Iterable<void Function(IContext)> get preCallHooks =>
      checks.map((e) => e.preCallHooks).expand((_) => _);

  @override
  Iterable<void Function(IContext)> get postCallHooks =>
      checks.map((e) => e.postCallHooks).expand((_) => _);
}

class RoleCheck extends Check {
  Iterable<Snowflake> roleIds;

  RoleCheck(IRole role, [String? name]) : this.id(role.id, name);

  RoleCheck.id(Snowflake id, [String? name])
      : roleIds = [id],
        super(
          (context) => context.member?.roles.any((role) => role.id == id) ?? false,
          name ?? 'Role Check on $id',
        );

  RoleCheck.any(Iterable<IRole> roles, [String? name])
      : this.anyId(roles.map((role) => role.id), name);

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

class UserCheck extends Check {
  Iterable<Snowflake> userIds;

  UserCheck(IUser user, [String? name]) : this.id(user.id, name);

  UserCheck.id(Snowflake id, [String? name])
      : userIds = [id],
        super((context) => context.user.id == id, name ?? 'User Check on $id');

  UserCheck.any(Iterable<IUser> users, [String? name])
      : this.anyId(users.map((user) => user.id), name);

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

class GuildCheck extends Check {
  Iterable<Snowflake?> guildIds;

  GuildCheck(IGuild guild, [String? name]) : this.id(guild.id, name);

  GuildCheck.id(Snowflake id, [String? name])
      : guildIds = [id],
        super((context) => context.guild?.id == id, name ?? 'Guild Check on $id');

  GuildCheck.none([String? name])
      : guildIds = [],
        super((context) => context.guild == null, name ?? 'Guild Check on <none>');

  GuildCheck.all([String? name])
      : guildIds = [null],
        super(
          (context) => context.guild != null,
          name ?? 'Guild Check on <any>',
        );

  GuildCheck.any(Iterable<IGuild> guilds, [String? name])
      : this.anyId(guilds.map((guild) => guild.id), name);

  GuildCheck.anyId(Iterable<Snowflake> ids, [String? name])
      : guildIds = ids,
        super(
          (context) => ids.contains(context.guild?.id),
          name ?? 'Guild Check on any of [${ids.join(', ')}]',
        );
}
