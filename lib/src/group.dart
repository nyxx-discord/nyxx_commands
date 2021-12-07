part of nyxx_commands;

/// A [Group] is a collection of commands. This mixin implements that functionality.
///
/// All [Group]s, [Command]s and [Bot]s use this mixin to enable nesting and registration of
/// commands.
mixin GroupMixin {
  /// A mapping of child names to children.
  ///
  /// Used for easier lookup of children based on both [name] and [aliases].
  final Map<String, GroupMixin> childrenMap = {};

  /// An iterable of all this groups children.
  ///
  /// Each child is only present once, and in no particular order.
  Iterable<GroupMixin> get children => Set.of(childrenMap.values);

  GroupMixin? _parent;

  /// The name of this group.
  String get name;

  /// A list of aliases that can also be used to refer to this group.
  Iterable<String> get aliases;

  /// A description of what this group represents.
  String get description;

  final List<Check> _checks = [];

  /// A list of functions that must return `true` for any descendant of this group to be executed.
  /// These are called before command invocation and can cause it to fail.
  ///
  /// If you only want to apply a check to a specific command and not all descendants, see
  /// [Command.singleChecks]
  Iterable<Check> get checks => [...?_parent?.checks, ..._checks];

  /// The full name of this group.
  ///
  /// The full name of a group is its name appended to its parents [fullName].
  String get fullName => (_parent == null || _parent is Bot ? '' : _parent!.name + ' ') + name;

  /// The depth of this group.
  ///
  /// If this group is a root group, the depth will be 0.
  /// If not, it will be the number of ancestors this group has.
  int get depth => (_parent?.depth ?? -1) + 1;

  /// Whether this group contains any slash commands.
  ///
  /// These might not be direct children, and can be nested multiple layers for this method to
  /// return true.
  bool get hasSlashCommand {
    return children.any((child) {
      if (child is Command) {
        return child.type != CommandType.textOnly || child.hasSlashCommand;
      }
      return child.hasSlashCommand;
    });
  }

  final Logger _logger = Logger('Commands');

  /// Get a [Command] based off a [StringView].
  ///
  /// This is usually used to obtain the command being executed in a message, after the prefix has
  /// been skipped in the view.
  Command? getCommand(StringView view) {
    String name = view.getWord();

    if (childrenMap.containsKey(name)) {
      GroupMixin child = childrenMap[name]!;

      if (child is Command && child.type != CommandType.slashOnly) {
        Command? found = child.getCommand(view);

        if (found == null) {
          return child;
        }

        return found;
      } else {
        return child.getCommand(view);
      }
    }

    view.undo();
    return null;
  }

  /// Add a child to this group.
  ///
  /// If any of its name or aliases confict with already registered commands, a
  /// [DuplicateNameException] is thrown.
  ///
  /// If [child] already has a parent, an [AlreadyRegisteredException] is thrown.
  void registerChild(GroupMixin child) {
    if (childrenMap.containsKey(child.name)) {
      throw CommandRegistrationError('Command with name "$fullName ${child.name}" already exists');
    }

    for (final alias in child.aliases) {
      if (childrenMap.containsKey(alias)) {
        throw CommandRegistrationError('Command with alias "$fullName $alias" already exists');
      }
    }

    if (child._parent != null) {
      throw CommandRegistrationError('Cannot register command "${child.fullName}" again');
    }

    if (_parent != null) {
      _logger.warning('Registering commands to a group after it is registered might cause slash '
          'commands to have incomplete definitions');
    }

    child._parent = this;

    childrenMap[child.name] = child;
    for (final alias in child.aliases) {
      childrenMap[alias] = child;
    }
  }

  /// Iterate over all the commands in this group and any subgroups.
  Iterable<Command> walkCommands() sync* {
    if (this is Command) {
      yield this as Command;
    }

    for (final child in children) {
      yield* child.walkCommands();
    }
  }

  /// Build the options for registering this group to the Discord API for slash commands.
  Iterable<CommandOptionBuilder> getOptions(Bot bot) {
    List<CommandOptionBuilder> options = [];

    for (final child in children) {
      if (child.hasSlashCommand) {
        options.add(CommandOptionBuilder(
          CommandOptionType.subCommandGroup,
          child.name,
          child.description,
          options: List.of(child.getOptions(bot)),
        ));
      } else if (child is Command && child.type != CommandType.textOnly) {
        options.add(CommandOptionBuilder(
          CommandOptionType.subCommand,
          child.name,
          child.description,
          options: List.of(child.getOptions(bot)),
        ));
      }
    }

    return options;
  }

  /// Add a check to this groups [checks].
  void check(Check check) => _checks.add(check);
}

/// A [Group] is a simple class that allows [GroupMixin]s to be instanciated.
///
/// This allows [GroupMixin] functionality to be used without the additional bloat of a [Command] or
/// [Bot]
class Group with GroupMixin {
  @override
  String name;
  @override
  String description;
  @override
  Iterable<String> aliases;

  /// Construct a new [Group]
  Group(
    this.name,
    this.description, {
    this.aliases = const [],
    Iterable<GroupMixin> children = const [],
    Iterable<Check> checks = const [],
  }) {
    if (!commandNameRegexp.hasMatch(name)) {
      throw CommandRegistrationError('Invalid group name "$name"');
    }

    for (final child in children) {
      registerChild(child);
    }

    for (final check in checks) {
      super.check(check);
    }
  }

  @override
  String toString() => 'Group[name="$name", fullName="$fullName"]';
}
