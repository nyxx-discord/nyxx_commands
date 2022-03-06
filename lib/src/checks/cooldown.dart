import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../context/context.dart';
import 'checks.dart';

/// An enum that represents the different ways to sort contexts into buckets.
///
/// Coolown types can be combined with the binary OR operator (`|`). For details on how this affects
/// how contexts are sorted into buckets, see [CooldownCheck.getKey].
///
/// You might also be interested in:
/// - [CooldownCheck], the check that uses this enum.
class CooldownType extends IEnum<int> {
  /// A cooldown type that sorts contexts depending on the category they were invoked from.
  ///
  /// If the channel the context was created in is not part of a category, then this type behaves
  /// the same as [channel].
  static const CooldownType category = CooldownType(1 << 0);

  /// A cooldown type that sorts contexts depending on the channel they were invoked from.
  static const CooldownType channel = CooldownType(1 << 1);

  /// A cooldown type that sorts contexts depending on the command being invoked.
  static const CooldownType command = CooldownType(1 << 2);

  /// A cooldown type that sorts all contexts into the same bucket.
  static const CooldownType global = CooldownType(1 << 3);

  /// A cooldown type that sorts contexts depending on the guild they were invoked from.
  ///
  /// If the context was not invoked from a guild, then this type behaves the same as [channel].
  static const CooldownType guild = CooldownType(1 << 4);

  /// A cooldown type that sorts contexts depending on the highest-level role the user invoking the
  /// command has.
  ///
  /// If the user has no role, then the [IGuild.everyoneRole] for that guild is used.
  /// If the context was not invoked from a guild, then this type behaves the same as [user].
  static const CooldownType role = CooldownType(1 << 5);

  /// A cooldown type that sorts contexts depending on the user that invoked them.
  static const CooldownType user = CooldownType(1 << 6);

  /// Create a new [CooldownType].
  ///
  /// Using a [value] other than the predefined ones will not result in any new behaviour, so using
  /// this constructor is discouraged.
  const CooldownType(int value) : super(value);

  /// Combine two cooldown types.
  ///
  /// For details on how cooldown types are combined, see [CooldownCheck.getKey].
  CooldownType operator |(CooldownType other) => CooldownType(value | other.value);

  /// Return whether [check] applies to [instance].
  ///
  /// A type is considered to *apply* to another if all the values making up that type are also
  /// present in the other type.
  ///
  /// For example, `CooldownType.user` applies to `CooldownType.user | CooldownType.guild` while
  /// `CooldownType.channel` does not.
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

/// A check that succeeds if a command is not on cooldown for a given context.
///
/// Every context can be sorted into "buckets", determined by [type]. See [getKey] for more
/// information on how these buckets are created.
///
/// Each bucket is allowed to execute commands a certain number of times before being put on
/// cooldown. This number is determined by [tokensPer], and the cooldown for a bucket starts as soon
/// as the bucket uses its first token. Once the cooldown is over, the number of tokens for that
/// bucket is reset to [tokensPer].
///
/// For example, a cooldown that puts individual users on cooldown for 2 minutes:
///
/// ```dart
///commands.check(CooldownCheck(
///   CooldownType.user,
///   Duration(minutes: 2),
/// ));
///
/// commands.addCommand(ChatCommand(
///   'test',
///   'A test command',
///   (IChatContext context) => context.respond(MessageBuilder.content('Hi there!')),
/// ));
///
/// commands.onCommandError.listen((error) {
///   if (error is CheckFailedException) {
///     AbstractCheck failed = error.failed;
///
///     if (failed is CooldownCheck) {
///       error.context.respond(MessageBuilder.content(
///         'Wait ${failed.remaining(error.context).inSeconds} '
///         'seconds before using that command again!',
///       ));
///     }
///   }
/// });
/// ```
///
/// *Notice the times at which the commands were executed, and that other users are not put on
/// cooldown*
/// ![](https://user-images.githubusercontent.com/54505189/153884640-4098fd83-3a39-41a6-bdf9-e79102d73b60.png)
///
/// You might also be interested in:
/// - [CooldownType], for determining how to sort contexts into buckets.
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

  /// Create a new [CooldownCheck] with a given [type] and [duration].
  ///
  /// [tokensPer] is optional and defaults to one, meaning a bucket can execute one before it is
  /// considered "on cooldown" for a given bucket.
  CooldownCheck(this.type, this.duration, [this.tokensPer = 1, String? name])
      : super(name ?? 'Cooldown Check on $type');

  /// The number of times a bucket can execute commands before this check fails.
  int tokensPer;

  /// The duration of the cooldown.
  Duration duration;

  /// The cooldown type, used to sort contexts into buckets.
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

  /// Returns an ID that uniquely represents the bucket [context] was sorted on, based on [type].
  ///
  /// For simple [type]s, this process is simple enough. For example, if [type] is
  /// [CooldownType.channel], then this method returns an ID that uniquely represents the context's
  /// ID (more precisely, `Object.hashAll([context.channel.id.id])`), and all contexts executed in that
  /// channel will be given the same ID.
  ///
  /// For combined [type]s, the process is different. For example, if [type] is
  /// `CooldownType.guild | CooldownType.user`, then this method returns an ID that uniquely
  /// represents the *combination* of the context's user and guild (more precisely,
  /// `Object.hashAll([context.guild.id.id, context.user.id.id])`). This means that:
  /// - Same user, same guild: same key;
  /// - Different user, different guild: different key;
  /// - Same guild, different user: different key;
  /// - Different guild, Different user: different key.
  ///
  /// You might also be interested in:
  /// - [type], which determines which values from [context] are combined to create a key.
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

  /// Return the remaining cooldown time for a given context.
  ///
  /// If the context is not on cooldown, [Duration.zero] is returned.
  ///
  /// You might also be interested in:
  /// - [getKey], for getting the ID of the bucket the context was sorted into.
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
