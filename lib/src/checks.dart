part of nyxx_commands;

/// Represents a check executed on a [Command].
///
/// All checks must succeed in order for a [Command] to be executed.
class Check {
  /// The name of the check.
  final String name;

  /// The function called to validate this check.
  final FutureOr<bool> Function(Context) check;

  /// Creates a new [Check].
  ///
  /// [check] should return a bool indicating whether this check succeeded.
  /// It should not throw.
  Check(this.check, [this.name = 'Check']);

  /// Creates a new [Check] that succeeds if at least one of the supplied checks succeed.
  static Check any(Iterable<Check> checks, [String? name]) => _AnyCheck(checks, name);

  /// Creates a new [Check] that inverts the result of the supplied check. Use this to allow use of
  /// commands by default but deny it for cecrtain users.
  static Check deny(Check check, [String? name]) => _DenyCheck(check, name);

  /// A Iterable of permission overrides that will be used on slash commands using this check.
  Future<Iterable<ICommandPermissionBuilder>> get permissions => Future.value([]);
}

class _AnyCheck extends Check {
  Iterable<Check> checks;

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
  Future<Iterable<ICommandPermissionBuilder>> get permissions async {
    Iterable<Iterable<ICommandPermissionBuilder>> permissions =
        await Future.wait(checks.map((check) => check.permissions));

    return permissions.first.where(
      (permission) =>
          permission.hasPermission ||
          // If permission is not granted, we check that it is not allowed by any of the other
          // checks. If every check denies the permission for this id, also deny the permission in
          // the combined version.
          permissions.every((element) => element.any(
                // ICommandPermissionBuilder does not override == so we manually check it
                (p) => p.id == permission.id && !p.hasPermission,
              )),
    );
  }
}

class _DenyCheck extends Check {
  final Check source;

  _DenyCheck(this.source, [String? name])
      : super((context) async => !(await source.check(context)), name ?? 'Denied ${source.name}');

  @override
  Future<Iterable<ICommandPermissionBuilder>> get permissions async {
    Iterable<ICommandPermissionBuilder> permissions = await source.permissions;

    Iterable<RoleCommandPermissionBuilder> rolePermissions =
        permissions.whereType<RoleCommandPermissionBuilder>();

    Iterable<UserCommandPermissionBuilder> userPermissions =
        permissions.whereType<UserCommandPermissionBuilder>();

    return [
      ...rolePermissions.map((permission) =>
          ICommandPermissionBuilder.role(permission.id, hasPermission: !permission.hasPermission)),
      ...userPermissions
          .map((e) => ICommandPermissionBuilder.user(e.id, hasPermission: !e.hasPermission)),
    ];
  }
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
  RoleCheck(Role role, [String? name]) : this.id(role.id, name);

  /// Create a new Role Check based on a role id.
  RoleCheck.id(Snowflake id, [String? name])
      : roleIds = [id],
        super(
          (context) => context.member?.roles.any((role) => role.id == id) ?? false,
          name ?? 'Role Check on $id',
        );

  /// Create a new Role Check based on multiple roles.
  RoleCheck.any(Iterable<Role> roles, [String? name])
      : this.anyId(roles.map((role) => role.id), name);

  /// Create a new Role Check based on multiple role ids.
  RoleCheck.anyId(Iterable<Snowflake> roles, [String? name])
      : roleIds = roles,
        super(
          (context) => context.member?.roles.any((role) => roles.contains(role.id)) ?? false,
          name ?? 'Role Check on any of [${roles.join(', ')}]',
        );

  @override
  Future<Iterable<ICommandPermissionBuilder>> get permissions => Future.value([
        ICommandPermissionBuilder.role(Snowflake.zero(), hasPermission: false),
        ...roleIds.map((e) => ICommandPermissionBuilder.role(e, hasPermission: true)),
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
  UserCheck(User user, [String? name]) : this.id(user.id, name);

  /// Create a User Check based on a user id.
  UserCheck.id(Snowflake id, [String? name])
      : userIds = [id],
        super((context) => context.user.id == id, name ?? 'User Check on $id');

  /// Create a User Check based on multiple users.
  UserCheck.any(Iterable<User> users, [String? name])
      : this.anyId(users.map((user) => user.id), name);

  /// Create a User Check based on multiple user ids.
  UserCheck.anyId(Iterable<Snowflake> ids, [String? name])
      : userIds = ids,
        super(
          (context) => ids.contains(context.user.id),
          name ?? 'User Check on any of [${ids.join(', ')}]',
        );

  @override
  Future<Iterable<ICommandPermissionBuilder>> get permissions => Future.value([
        ICommandPermissionBuilder.user(Snowflake.zero(), hasPermission: false),
        ...userIds.map((e) => ICommandPermissionBuilder.user(e, hasPermission: true)),
      ]);
}

/// A [Check] that checks for a specific guild.
///
/// This check is treated specially by [Bot]:
/// - There can only be one [GuildCheck] per command
/// - Commands will be registered as guild commands in the specified guilds. This overrides
/// [Bot.guild]
class GuildCheck extends Check {
  /// The guilds this check allows.
  ///
  /// [null] indicates that all guilds are allowed.
  Iterable<Snowflake?> guildIds;

  /// Create a Guild Check based on a guild.
  GuildCheck(Guild guild, [String? name]) : this.id(guild.id, name);

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
  /// by [Bot.guild], and cannot be used in DMs with the bot.
  GuildCheck.all([String? name])
      : guildIds = [null],
        super(
          (context) => context.guild != null,
          name ?? 'Guild Check on <any>',
        );

  /// Create a Guild Check based on multiple guilds.
  GuildCheck.any(Iterable<Guild> guilds, [String? name])
      : this.anyId(guilds.map((guild) => guild.id), name);

  /// Creatte a Guild Check based on multiple guild ids.
  GuildCheck.anyId(Iterable<Snowflake> ids, [String? name])
      : guildIds = ids,
        super(
          (context) => ids.contains(context.guild?.id),
          name ?? 'Guild Check on any of [${ids.join(', ')}]',
        );
}
