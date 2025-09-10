import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../commands/chat_command.dart';
import '../commands/interfaces.dart';
import '../context/autocomplete_context.dart';
import '../converters/converter.dart';
import 'view.dart';

/// Convert a camelCase string to kebab-case.
///
/// This is used to convert camelCase Dart identifiers to kebab-case Discord Slash Command argument
/// names.
///
/// You might also be interested in:
/// - [Name], for setting a custom name to use for slash command argument names.
String convertToKebabCase(String camelCase) {
  Iterable<String> split = camelCase.split('');
  String res = '';

  for (final char in split) {
    if (char != char.toLowerCase() && res.isNotEmpty) {
      res += '-';
    }
    res += char.toLowerCase();
  }

  return res;
}

/// An annotation used to add a description to Slash Command arguments.
///
/// For example, these two snippets of code produce different results:
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (IChatContext context, String message) async {
///     context.respond(MessageBuilder.content(message));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
/// and
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Description('The message to send') String message,
///   ) async {
///     context.respond(MessageBuilder.content(message));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156934401-67535127-d768-4687-b4b4-d279e4362e16.png)
/// ![](https://user-images.githubusercontent.com/54505189/156934465-18693d88-66f4-41a0-8615-f7d18293fb86.png)
class Description {
  /// The value of the description.
  final String value;

  /// The localized descriptions for the command.
  ///
  /// ```dart
  /// ChatCommand test = ChatCommand(
  ///  'hi',
  ///  'A test command',
  ///   (
  ///     IChatContext context,
  ///     @Description('This is a description', {Locale.german: 'Dies ist eine Beschreibung'})
  ///         String foo,
  ///   ) async {
  ///     context.respond(MessageBuilder.content(foo));
  ///   },
  /// );
  /// ```
  /// Will be displayed as `This is a description` in English, but `Dies ist eine Beschreibung` in German, like so:
  ///
  /// ![](https://user-images.githubusercontent.com/74512338/174033266-88017e8a-bc13-4031-bf9d-31f9343967a4.png)
  final Map<Locale, String>? localizedDescriptions;

  /// Create a new [Description].
  ///
  /// This is intended to be used as an `@Description(...)` annotation, and has no functionality as
  /// a standalone class.
  const Description(this.value, [this.localizedDescriptions]);

  @override
  String toString() => 'Description[value="$value", localizedDescription=$localizedDescriptions]';
}

/// An annotation used to restrict input to a set of choices for a given parameter.
///
/// Note that this is only a client-side verification for Slash Commands only, input from text
/// commands might not be one of the options.
///
/// For example, adding three choices to a command:
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Choices({'Foo': 'foo', 'Bar': 'bar', 'Baz': 'baz'}) String message,
///   ) async {
///     context.respond(MessageBuilder.content(message));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156936191-d35e18d0-5e03-414d-938e-b14c80071175.png)
class Choices {
  /// The choices for this command.
  ///
  /// The keys are what is displayed in the Discord UI when the user selects your command and the
  /// values are what actually get sent to your command.
  ///
  /// The values can be either [String]s or [int]s.
  ///
  /// You might also be interested in:
  /// - [CommandOptionChoiceBuilder], the nyxx_interactions builder these entries are converted to.
  final Map<String, dynamic> choices;

  /// Create a new [Choices].
  ///
  /// This is intended to be used as an `@Choices(...)` annotation, and has no functionality as
  /// a standalone class.
  const Choices(this.choices);

  /// Get the builders that this [Choices] represents.
  Iterable<CommandOptionChoiceBuilder<dynamic>> get builders => choices.entries.map((entry) => CommandOptionChoiceBuilder(name: entry.key, value: entry.value));

  @override
  String toString() => 'Choices[choices=$choices]';
}

/// An annotation used to change the name displayed in the Discord UI for a given command argument.
///
/// For example, changing the name of an argument from 'foo' to 'message':
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Name('message') String foo,
///   ) async {
///     context.respond(MessageBuilder.content(foo));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156937204-bbcd5c95-ff0f-40c2-944d-9988fd7b6a60.png)
class Name {
  /// The custom name to use.
  final String name;

  /// The localized names to use.
  /// ```dart
  /// ChatCommand test = ChatCommand(
  ///  'hi',
  ///  'A test command',
  ///  (
  ///   IChatContext context,
  ///   @Name('message', {Locale.german: 'hallo'}) String foo,
  ///  ) async => context.respond(MessageBuilder.content(foo))
  /// );
  /// ```
  /// Will be displayed as 'hallo' in German, like so:
  ///
  /// ![](https://user-images.githubusercontent.com/74512338/173841767-6e2c5215-ebc3-4a89-a2ac-8115949e2f0b.png)
  final Map<Locale, String>? localizedNames;

  /// Create a new [Name].
  ///
  /// This is intended to be used as an `@Name(...)` annotation, and has no functionality as
  /// a standalone class.
  const Name(this.name, [this.localizedNames]);

  @override
  String toString() => 'Name[name=$name, localizedNames=$localizedNames]';
}

/// An annotation used to specify the converter to use for an argument, overriding the default
/// converter for that type.
///
/// See example/example.dart for an example on how to use this annotation.
class UseConverter {
  /// The converter to use.
  final Converter<dynamic> converter;

  /// Create a new [UseConverter].
  ///
  /// This is intended to be used as an `@UseConverter(...)` annotation, and has no functionality as
  /// a standalone class.
  const UseConverter(this.converter);

  @override
  String toString() => 'UseConverter[converter=$converter]';
}

/// An annotation used to override the callback used to handle autocomplete events for a specific
/// argument.
///
/// For example, using the top-level function `foo` as an autocomplete handler:
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Autocomplete(foo) String bar,
///   ) async {
///     context.respond(MessageBuilder.content(bar));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// You might also be interested in:
/// - [Converter.autocompleteCallback], the way to register autocomplete handlers for all arguments
///   of a given type.
class Autocomplete {
  /// The autocomplete handler to use.
  final FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext) callback;

  /// Create a new [Autocomplete].
  ///
  /// This is intended to be used as an `@Autocomplete(...)` annotation, and has no functionality as
  /// a standalone class.
  const Autocomplete(this.callback);
}

final RegExp _mentionPattern = RegExp(r'^<@!?([0-9]{15,20})>');

/// A wrapper function for prefixes that allows commands to be invoked with a mention prefix.
///
/// For example:
/// ```dart
/// CommandsPlugin commands = CommandsPlugin(
///   prefix: mentionOr((_) => '!'),
/// );
///
/// // Add a basic `test` command...
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156937410-73d19cc5-c018-40e4-97dd-b7fcc0be0b7d.png)
Future<String> Function(MessageCreateEvent) mentionOr(
  FutureOr<String> Function(MessageCreateEvent) defaultPrefix,
) {
  return (event) async {
    RegExpMatch? match = _mentionPattern.firstMatch(event.message.content);

    if (match != null) {
      if (int.parse(match.group(1)!) == (await event.gateway.client.users.fetchCurrentUser()).id.value) {
        return match.group(0)!;
      }
    }

    return defaultPrefix(event);
  };
}

/// A wrapper function for prefixes that allows commands to be invoked from messages without a
/// prefix in Direct Messages.
///
/// For example:
/// ```dart
/// CommandsPlugin commands = CommandsPlugin(
///   prefix: dmOr((_) => '!'),
/// );
///
/// // Add a basic `test` command...
/// ```
/// ![](https://user-images.githubusercontent.com/54505189/156937528-df54a2ba-627d-4f54-b0bc-ad7cb6321965.png)
/// ![](https://user-images.githubusercontent.com/54505189/156937561-9df9e6cf-6595-465d-895a-aaca5d6ff066.png)
Future<String> Function(MessageCreateEvent) dmOr(FutureOr<String> Function(MessageCreateEvent) defaultPrefix) {
  return (event) async {
    String found = await defaultPrefix(event);

    if (event.guild != null || StringView(event.message.content).skipString(found)) {
      return found;
    }

    return '';
  };
}

/// A pattern all command and argument names should match.
///
/// For more information on naming restrictions, check the
/// [Discord documentation](https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-naming).
final RegExp commandNameRegexp = RegExp(
  r'^[-_\p{L}\p{N}\p{sc=Deva}\p{sc=Thai}]{1,32}$',
  unicode: true,
);

final Map<Function, dynamic> idMap = {};

/// A special function that can be wrapped around another function in order to tell nyxx_commands
/// how to identify the function at compile time.
///
/// This function is used to identify a callback function so that compiled nyxx_commands can extract
/// the type & annotation data for that function.
///
/// It is a compile-time error for two [id] invocations to share the same [id] parameter.
/// It is a runtime error in compiled nyxx_commands to create a [ChatCommand] with a non-wrapped
/// function.
T id<T extends Function>(dynamic id, T fn) {
  idMap[fn] = id;

  return fn;
}

ChatCommand? getCommandHelper(StringView view, Map<String, ChatCommandComponent> children) {
  String name = view.getWord();
  String lowerCaseName = name.toLowerCase();

  try {
    ChatCommandComponent child = children.entries.singleWhere((childEntry) {
      bool isCaseInsensitive = childEntry.value.resolvedOptions.caseInsensitiveCommands!;

      if (isCaseInsensitive) {
        return lowerCaseName == childEntry.key.toLowerCase();
      }

      return name == childEntry.key;
    }).value;

    ChatCommand? commandFromChild = child.getCommand(view);

    // If no command further down the tree was found, return the child if it is a chat command
    // that can be invoked from a text message (not slash only).
    if (commandFromChild == null && child is ChatCommand && child.resolvedOptions.type != CommandType.slashOnly) {
      return child;
    }

    return commandFromChild;
  } on StateError {
    // Don't consume any input if no command was found.
    view.undo();
    return null;
  }
}

/// An identifier for message components containing metadata about the handler associated with the
/// component.
///
/// This class contains the data needed for nyxx_commands to find the correct handler for a
/// component interaction event, and throw an error if no handler is found.
///
/// Call [toString] to get the custom id to use on a component. A new [ComponentId] shhould be used
/// for each component.
///
/// [ComponentId]s should not be stored before use. See [expiresAt] for the reason why.
class ComponentId {
  /// A unique identifier (in this process) for this component.
  ///
  /// Every [ComponentId] will get a new [uniqueIdentifier].
  final int uniqueIdentifier;

  /// The time at which the process that created this [ComponentId] was started.
  ///
  /// This will be the same for all [ComponentId]s created in the same process and allows
  /// nyxx_commands to tell when an interaction comes from a previous session, meaning no handler
  /// will be found.
  final DateTime sessionStartTime;

  /// If the handler associated with this component has an expiration timeout, the time at which it
  /// will expire, otherwise null.
  ///
  /// This is set as soon as this [ComponentId] is created, so [ComponentId]s should be used as soon
  /// as they are created.
  final DateTime? expiresAt;

  /// If the handler associated with this component only allows a specific user to use the
  /// component, the ID of that user, otherwise null.
  final Snowflake? allowedUser;

  /// The time remaining until the handler for this [ComponentId] expires, if [expiresAt] was set.
  Duration? get expiresIn => expiresAt?.difference(DateTime.now());

  /// The status of this [ComponentId].
  ///
  /// This will always be [ComponentIdStatus.ok] for [ComponentId]s created using
  /// [ComponentId.generate] but will contain information about the status of the handler if this
  /// [ComponentId] was received from the API and created using [ComponentId.parse].
  final ComponentIdStatus status;

  /// The start time of the current session.
  ///
  /// This will be the value of [ComponentId.sessionStartTime] for all [ComponentId]s created in
  /// this process.
  static final currentSessionStartTime = DateTime.now().toUtc();

  static int _uniqueIdentifier = 0;

  /// Create a new [ComponentId].
  const ComponentId({
    required this.uniqueIdentifier,
    required this.sessionStartTime,
    required this.expiresAt,
    required this.status,
    required this.allowedUser,
  });

  /// Generate a new unique [ComponentId].
  ///
  /// [expirationTime] should be the time after which the handler will expire. [allowedUser] should
  /// be the ID of the user allows to interact with this component.
  factory ComponentId.generate({Duration? expirationTime, Snowflake? allowedUser}) => ComponentId(
        uniqueIdentifier: _uniqueIdentifier++,
        sessionStartTime: currentSessionStartTime,
        expiresAt: expirationTime != null ? DateTime.now().add(expirationTime).toUtc() : null,
        status: ComponentIdStatus.ok,
        allowedUser: allowedUser,
      );

  /// Parse a [ComponentId] received from the API.
  ///
  /// This method parses the string returned by a call to [toString].
  ///
  /// If [id] was not a [ComponentId] created by nyxx_commands, such as a manually set custom id,
  /// this method will return `null`.
  static ComponentId? parse(String id) {
    final parts = id.split('/');

    if (parts.isEmpty || parts.first != 'nyxx_commands') {
      return null;
    }

    final uniqueIdentifier = int.parse(parts[1]);
    final sessionStartTime = DateTime.parse(parts[2]);
    final expiresAt = parts[3] != 'null' ? DateTime.parse(parts[3]) : null;
    final allowedUser = parts[4] != 'null' ? Snowflake.parse(parts[4]) : null;

    final ComponentIdStatus? status;
    if (sessionStartTime != currentSessionStartTime) {
      status = ComponentIdStatus.fromDifferentSession;
    } else if (expiresAt?.isBefore(DateTime.now()) ?? false) {
      status = ComponentIdStatus.expired;
    } else {
      status = ComponentIdStatus.ok;
    }

    return ComponentId(
      expiresAt: expiresAt,
      sessionStartTime: sessionStartTime,
      status: status,
      uniqueIdentifier: uniqueIdentifier,
      allowedUser: allowedUser,
    );
  }

  /// Copy this [ComponentId] with a new status.
  ComponentId withStatus(ComponentIdStatus status) => ComponentId(
        expiresAt: expiresAt,
        sessionStartTime: sessionStartTime,
        status: status,
        uniqueIdentifier: uniqueIdentifier,
        allowedUser: allowedUser,
      );

  @override
  // When adding new fields, ensure we don't go over the maximum length (100).
  // Current length:
  //   13 - nyxx_commands prefix
  //   4  - / separators
  //   6  - uniqueIdentifier (assume we won't go over 1 000 000 interactions in one session)
  //   27 - sessionStartTime
  //   27 - expiresAt
  //   19 - allowedUser
  // Total: 96, 4 free (could be used up by uniqueIdentifier)
  // TODO: Serialize to binary => encode base64?
  String toString() => 'nyxx_commands/$uniqueIdentifier/$sessionStartTime/$expiresAt/$allowedUser';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComponentId &&
          other.uniqueIdentifier == uniqueIdentifier &&
          other.sessionStartTime == sessionStartTime &&
          other.expiresAt == expiresAt &&
          other.allowedUser == allowedUser);

  @override
  int get hashCode => Object.hash(uniqueIdentifier, sessionStartTime, expiresAt, allowedUser);
}

/// The status of the handler associated with a [ComponentId].
enum ComponentIdStatus {
  /// No problems.
  ///
  /// This status shouldn't ever occur in an error.
  ok,

  /// The [ComponentId] was created in a different process, so no handler could be found.
  ///
  /// This also means that the state associated with the handler is now lost.
  fromDifferentSession,

  /// The handler for this [ComponentId] has expired.
  expired,

  /// No handler for this [ComponentId] was found.
  ///
  /// This can happen when two instances of nyxx_commands are running at the same time, so the event
  /// will probably be handled by the other instance.
  noHandlerFound,

  /// The user who interacted with the component was not allowed to do so.
  wrongUser;

  @override
  String toString() {
    switch (this) {
      case ComponentIdStatus.ok:
        return 'OK';
      case ComponentIdStatus.fromDifferentSession:
        return 'From different session';
      case ComponentIdStatus.expired:
        return 'Expired';
      case ComponentIdStatus.noHandlerFound:
        return 'No handler found';
      case ComponentIdStatus.wrongUser:
        return 'User not allowed';
    }
  }
}

class MessageCreateUpdateBuilder extends MessageBuilder implements MessageUpdateBuilder {
  MessageCreateUpdateBuilder({
    super.content,
    super.nonce,
    super.tts,
    super.embeds,
    super.allowedMentions,
    super.replyId,
    super.requireReplyToExist,
    super.components,
    super.stickerIds,
    super.attachments,
    super.suppressEmbeds,
    super.suppressNotifications,
  });

  MessageCreateUpdateBuilder.fromMessageBuilder(MessageBuilder builder)
      : this(
          content: builder.content,
          nonce: builder.nonce,
          tts: builder.tts,
          embeds: builder.embeds,
          allowedMentions: builder.allowedMentions,
          replyId: builder.replyId,
          requireReplyToExist: builder.requireReplyToExist,
          components: builder.components,
          stickerIds: builder.stickerIds,
          attachments: builder.attachments,
          suppressEmbeds: builder.suppressEmbeds,
          suppressNotifications: builder.suppressNotifications,
        );
}

/// Adapted from https://discord.com/developers/docs/topics/permissions
Future<Permissions> computePermissions(
  Guild guild,
  GuildChannel channel,
  Member member,
) async {
  Future<Permissions> computeBasePermissions() async {
    if (guild.ownerId == member.id) {
      return Permissions.allPermissions;
    }

    final everyoneRole = await guild.roles[guild.id].get();
    Flags<Permissions> permissions = everyoneRole.permissions;

    for (final role in member.roles) {
      final rolePermissions = (await role.get()).permissions;

      permissions |= rolePermissions;
    }

    permissions = Permissions(permissions.value);
    permissions as Permissions;

    if (permissions.isAdministrator) {
      return Permissions.allPermissions;
    }

    return permissions;
  }

  Future<Permissions> computeOverwrites(Permissions basePermissions) async {
    if (basePermissions.isAdministrator) {
      return Permissions.allPermissions;
    }

    Flags<Permissions> permissions = basePermissions;

    final everyoneOverwrite = channel.permissionOverwrites.where((overwrite) => overwrite.id == guild.id).singleOrNull;
    if (everyoneOverwrite != null) {
      permissions &= ~everyoneOverwrite.deny;
      permissions |= everyoneOverwrite.allow;
    }

    Flags<Permissions> allow = Permissions(0);
    Flags<Permissions> deny = Permissions(0);

    for (final roleId in member.roleIds) {
      final roleOverwrite = channel.permissionOverwrites.where((overwrite) => overwrite.id == roleId).singleOrNull;
      if (roleOverwrite != null) {
        allow |= roleOverwrite.allow;
        deny |= roleOverwrite.deny;
      }
    }

    permissions &= ~deny;
    permissions |= allow;

    final memberOverwrite = channel.permissionOverwrites.where((overwrite) => overwrite.id == member.id).singleOrNull;
    if (memberOverwrite != null) {
      permissions &= ~memberOverwrite.deny;
      permissions |= memberOverwrite.allow;
    }

    return Permissions(permissions.value);
  }

  return computeOverwrites(await computeBasePermissions());
}
