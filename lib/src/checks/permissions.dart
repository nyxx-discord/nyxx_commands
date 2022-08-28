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

import '../commands/interfaces.dart';
import '../context/base.dart';
import 'checks.dart';

/// A check that succeeds if the member invoking the command has a certain set of permissions.
///
/// You might also be interested in:
/// - [UserCheck], for checking if a command was executed by a specific user;
/// - [RoleCheck], for checking if a command was executed by a user with a specific role.
class PermissionsCheck extends Check {
  /// The bitfield representing the permissions required by this check.
  ///
  /// You might also be interested in:
  /// - [PermissionsConstants], for computing the value for this field;
  /// - [AbstractCheck.requiredPermissions], for setting permissions on any check.
  final int permissions;

  /// Whether this check should allow server administrators to configure overrides that allow
  /// specific users or channels to execute this command regardless of permissions.
  final bool allowsOverrides;

  /// Whether this check requires the user invoking the command to have all of the permissions in
  /// [permissions] or only a single permission from [permissions].
  ///
  /// If this is true, the member invoking the command must have all the permissions in
  /// [permissions] to execute the command. Otherwise, members need only have one of the
  /// permissions in [permissions] to execute the command.
  final bool requiresAll;

  /// Create a new [PermissionsCheck].
  PermissionsCheck(
    this.permissions, {
    this.allowsOverrides = true,
    this.requiresAll = false,
    String? name,
    super.allowsDm = true,
  }) : super(
          name: name ?? 'Permissions check on $permissions',
          requiredPermissions: permissions,
          (context) async {
            IMember? member = context.member;

            if (member == null) {
              return allowsDm;
            }

            IPermissions effectivePermissions =
                await (context.channel as IGuildChannel).effectivePermissions(member);

            if (allowsOverrides) {
              ISlashCommand command;

              if (context is IInteractionCommandContextData) {
                command = context.commands.interactions.commands.firstWhere((command) =>
                    command.id ==
                    (context as IInteractionCommandContextData).interaction.commandId);
              } else {
                // If the invocation was not from a slash command, try to find a matching slash
                // command and use the overrides from that.
                ICommandRegisterable root = context.command;

                while (root.parent is ICommandRegisterable) {
                  root = root.parent as ICommandRegisterable;
                }

                Iterable<ISlashCommand> matchingCommands =
                    context.commands.interactions.commands.where(
                  (command) => command.name == root.name && command.type == SlashCommandType.chat,
                );

                if (matchingCommands.isEmpty) {
                  return false;
                }

                command = matchingCommands.first;
              }

              ISlashCommandPermissionOverrides overrides =
                  await command.getPermissionOverridesInGuild(context.guild!.id).getOrDownload();

              if (overrides.permissionOverrides.isEmpty) {
                overrides = await context.commands.interactions
                    .getGlobalOverridesInGuild(context.guild!.id)
                    .getOrDownload();
              }

              bool? def;
              bool? channelDef;
              bool? role;
              bool? channel;
              bool? user;

              int highestRoleIndex = -1;

              for (final override in overrides.permissionOverrides) {
                if (override.isEveryone) {
                  def = override.allowed;
                } else if (override.isAllChannels) {
                  channelDef = override.allowed;
                } else if (override.type == SlashCommandPermissionType.channel &&
                    override.id == context.channel.id) {
                  channel = override.allowed;
                } else if (override.type == SlashCommandPermissionType.role) {
                  int roleIndex = -1;

                  int i = 0;
                  for (final role in member.roles) {
                    if (role.id == override.id) {
                      roleIndex = i;
                      break;
                    }

                    i++;
                  }

                  if (highestRoleIndex < roleIndex) {
                    role = override.allowed;
                    highestRoleIndex = roleIndex;
                  }
                } else if (override.type == SlashCommandPermissionType.user &&
                    override.id == context.user.id) {
                  user = override.allowed;
                  // No need to continue if we found an override for the specific user
                  break;
                }
              }

              Iterable<bool> prioritised = [def, channelDef, role, channel, user].whereType<bool>();

              if (prioritised.isNotEmpty) {
                return prioritised.last;
              }
            }

            int corresponding = effectivePermissions.raw & permissions;

            if (requiresAll) {
              return corresponding == permissions;
            }

            return corresponding != 0;
          },
        );

  /// Create a [PermissionsCheck] that allows nobody to execute a command, unless configured
  /// otherwise by a permission override.
  PermissionsCheck.nobody({
    bool allowsOverrides = true,
    String? name,
    bool allowsDm = true,
  }) : this(0, allowsOverrides: allowsOverrides, allowsDm: allowsDm, name: name);
}
