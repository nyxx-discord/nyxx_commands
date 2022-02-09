import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// Represents different types of cooldown
class CooldownType extends IEnum<int> {
  /// Cooldown is per category.
  ///
  /// If the command is executed in a guild channel belonging to a category, the cooldown is set for
  /// all users in all channels belonging to that category.
  ///
  /// If the channel does not belong to a category or is not a guild channel, the cooldown works in
  /// the same way as [channel].
  static const CooldownType category = CooldownType(1 << 0);

  /// Cooldown is per channel.
  ///
  /// If the command is executed in a channel, then the cooldown is set for all users in that
  /// channel.
  static const CooldownType channel = CooldownType(1 << 1);

  /// Cooldown is per command.
  ///
  /// If the command is executed, then the cooldown is set for all users in all channels for that
  /// command.
  static const CooldownType command = CooldownType(1 << 2);

  /// Cooldown is global.
  ///
  /// Generally works in the same was as [command], but if the same [CooldownCheck] instance is used
  /// in multiple commands' [GroupMixin.checks] or [ChatCommand.singleChecks] then the cooldown will be
  /// set for all users in all channels for the commands sharing the [CooldownCheck] instance.
  static const CooldownType global = CooldownType(1 << 3);

  /// Cooldown is per guild.
  ///
  /// If the command is executed in a guild, then the cooldown is set for all users in all channels
  /// in that guild. If the command is executed outside of a guild, then the cooldown works in the
  /// same way as [channel].
  static const CooldownType guild = CooldownType(1 << 4);

  /// Cooldown is per role.
  ///
  /// If the command is executed in a guild by a member, then the command is set for all channels
  /// for all members with the same highest role as the member. If the command is executed by a
  /// member with no roles, the cooldown is set for all members with no roles. If the command is
  /// executed outside of a guild, the cooldown works in the same way as [channel].
  static const CooldownType role = CooldownType(1 << 5);

  /// Cooldown is per user.
  ///
  /// If the command is executed by a user, then the cooldown is set for all channels for that user.
  static const CooldownType user = CooldownType(1 << 6);

  const CooldownType(int value) : super(value);

  /// Combines two [CooldownType]s.
  CooldownType operator |(CooldownType other) => CooldownType(value | other.value);

  /// Returns `true` if all the types in [instance] are present in [check].
  static bool applies(CooldownType instance, CooldownType check) =>
      instance.value & check.value == check.value;

  @override
  String toString() {
    List<String> components = [];

    Map<CooldownType, String> names = {
      category: 'Category',
      channel: 'Channel',
      command: 'Command',
      global: 'Global',
      guild: 'Guild',
      role: 'Role',
      user: 'User',
    };

    for (final key in names.keys) {
      if (applies(this, key)) {
        components.add(names[key]!);
      }
    }

    return 'CooldownType[${components.join(', ')}]';
  }
}

class _BucketEntry {
  final DateTime start;
  int count = 1;

  _BucketEntry(this.start);
}

/// A [Check] that checks that a [ChatCommand] is not on cooldown.
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
  ///
  /// [type] can be any combination of [CooldownType]s. For example, to have a cooldown per command
  /// per user per guild, use the following type:
  /// `CooldownType.command | CooldownType.user | CooldownType.guild`
  ///
  /// Placing this check on the root [CommandsPlugin] will result in each command registered on the
  /// bot to apply an individual cooldown for each user in each guild.
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
  FutureOr<bool> check(IContext context) {
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

  /// Get a key representing a [IContext] depending on [type].
  int getKey(IContext context) {
    List<int> keys = [];

    if (CooldownType.applies(type, CooldownType.category)) {
      if (context.guild != null) {
        keys.add((context.channel as IGuildChannel).parentChannel?.id.id ?? context.channel.id.id);
      } else {
        keys.add(context.channel.id.id);
      }
    }

    if (CooldownType.applies(type, CooldownType.channel)) {
      keys.add(context.channel.id.id);
    }

    if (CooldownType.applies(type, CooldownType.command)) {
      keys.add(context.command.hashCode);
    }

    if (CooldownType.applies(type, CooldownType.global)) {
      keys.add(0);
    }

    if (type.value & CooldownType.guild.value != 0) {
      keys.add(context.guild?.id.id ?? context.user.id.id);
    }

    if (CooldownType.applies(type, CooldownType.role)) {
      if (context.member != null) {
        if (context.member!.roles.isNotEmpty) {
          keys.add(PermissionsUtils.getMemberHighestRole(context.member!).id.id);
        } else {
          keys.add(context.guild!.everyoneRole.id.id);
        }
      } else {
        keys.add(context.user.id.id);
      }
    }

    if (CooldownType.applies(type, CooldownType.user)) {
      keys.add(context.user.id.id);
    }

    return Object.hashAll(keys);
  }

  /// Get the remaining cooldown time for a context.
  ///
  /// If the context is not on cooldown, [Duration.zero] is returned.
  Duration remaining(IContext context) {
    if (check(context) as bool) {
      return Duration.zero;
    }

    DateTime now = DateTime.now();

    int key = getKey(context);
    if (_currentBucket.containsKey(key)) {
      DateTime end = _currentBucket[key]!.start.add(duration);

      return end.difference(now);
    }

    if (_previousBucket.containsKey(key)) {
      DateTime end = _previousBucket[key]!.start.add(duration);

      return end.difference(now);
    }

    return Duration.zero;
  }

  @override
  late Iterable<void Function(IContext)> preCallHooks = [
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
  Iterable<void Function(IContext p1)> get postCallHooks => [];
}
