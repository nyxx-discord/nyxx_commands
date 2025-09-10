import 'package:nyxx/nyxx.dart';

import 'checks.dart';

/// A check that checks that a command was executed in a particular guild, or in a channel that is
/// not in a guild.
///
/// This check is special as commands with this check will only be registered as slash commands in
/// the guilds specified by this guild check. For this functionality to work, however, this check
/// must be a "top-level" check - that is, a check that is not nested within a modifier such as
/// [Check.any], [Check.deny] or [Check.all].
///
/// The value of this check overrides [CommandsPlugin.guild].
///
/// This check integrates with the [Discord Slash Command Permissions](https://discord.com/developers/docs/interactions/application-commands#permissions)
/// API, so users that cannot use a command because of this check will have that command appear
/// unavailable out in their Discord client.
///
/// You might also be interested in:
/// - [CommandsPlugin.guild], for globally setting a guild to register slash commands to.
class GuildCheck extends Check {
  /// The IDs of the guilds that this check allows.
  ///
  /// If [guildIds] is `[null]`, then any guild is allowed, but not channels outside of guilds.
  Iterable<Snowflake?> guildIds;

  /// Create a [GuildCheck] that succeeds if the context originated in [guild].
  ///
  /// You might also be interested in:
  /// - [GuildCheck.id], for creating this same check without an instance of [Guild];
  /// - [GuildCheck.any], for checking if the context originated in any of a set of guilds.
  GuildCheck(Guild guild, {String? name}) : this.id(guild.id, name: name);

  /// Create a [GuildCheck] that succeeds if the ID of the guild the context originated in is [id].
  GuildCheck.id(Snowflake id, {String? name})
      : guildIds = [id],
        super(
          (context) => context.guild?.id == id,
          name: name ?? 'Guild Check on $id',
          allowsDm: false,
        );

  /// Create a [GuildCheck] that succeeds if the context originated outside of a guild (generally,
  /// in private messages).
  ///
  /// You might also be interested in:
  /// - [GuildCheck.all], for checking that a context originated in a guild.
  GuildCheck.none({String? name})
      : guildIds = [],
        super(
          (context) => context.guild == null,
          name: name ?? 'Guild Check on <none>',
          allowsDm: true,
          requiredPermissions: Permissions(0),
        );

  /// Create a [GuildCheck] that succeeds if the context originated in a guild.
  ///
  /// You might also be interested in:
  /// - [GuildCheck.none], for checking that a context originated outside a guild.
  GuildCheck.all({String? name})
      : guildIds = [null],
        super(
          (context) => context.guild != null,
          name: name ?? 'Guild Check on <any>',
          allowsDm: false,
        );

  /// Create a [GuildCheck] that succeeds if the context originated in any of [guilds].
  ///
  /// You might also be interested in:
  /// - [GuildCheck.anyId], for creating the same check without instances of [Guild].
  GuildCheck.any(Iterable<Guild> guilds, {String? name}) : this.anyId(guilds.map((guild) => guild.id), name: name);

  /// Create a [GuildCheck] that succeeds if the id of the guild the context originated in is in
  /// [ids].
  GuildCheck.anyId(Iterable<Snowflake> ids, {String? name})
      : guildIds = ids,
        super(
          (context) => ids.contains(context.guild?.id),
          name: name ?? 'Guild Check on any of [${ids.join(', ')}]',
          allowsDm: false,
        );
}
