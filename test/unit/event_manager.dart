import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:test/test.dart';

void main() {
  group('EventManager with component events', () {
    test('completes with the correct event', () {
      final eventManager = EventManager(MockCommandsPlugin());

      final componentId = ComponentId.generate();
      final nextEventFuture = eventManager.nextButtonEvent(componentId);

      eventManager.processButtonEvent(MockButtonInteractionEvent(
        componentId.toString(),
        Snowflake.zero(),
      ));

      expect(nextEventFuture, completes);
    });

    test('times out if a timeout is specified', () {
      final eventManager = EventManager(MockCommandsPlugin());

      final componentId = ComponentId.generate(
        expirationTime: Duration(seconds: 1),
      );

      final nextEventFuture = eventManager.nextButtonEvent(componentId);

      expect(nextEventFuture, throwsA(isA<TimeoutException>()));
    });

    test('throws if an unknown user runs the interaction', () {
      final eventManager = EventManager(MockCommandsPlugin());

      final componentId = ComponentId.generate(
        allowedUser: Snowflake.zero(),
      );

      expect(
        () => eventManager.processButtonEvent(MockButtonInteractionEvent(
          componentId.toString(),
          Snowflake(1),
        )),
        throwsA(
          isA<UnhandledInteractionException>().having(
            (exception) => exception.reason,
            'reason is wrongUser',
            equals(ComponentIdStatus.wrongUser),
          ),
        ),
      );
    });

    test('throws if no handler was found', () {
      final eventManager = EventManager(MockCommandsPlugin());

      final componentId = ComponentId.generate();

      expect(
        () => eventManager.processButtonEvent(MockButtonInteractionEvent(
          componentId.toString(),
          Snowflake.zero(),
        )),
        throwsA(
          isA<UnhandledInteractionException>().having(
            (exception) => exception.reason,
            'reason is noHandlerFound',
            equals(ComponentIdStatus.noHandlerFound),
          ),
        ),
      );
    });
  });
}

class MockCommandsPlugin with Mock implements CommandsPlugin {
  @override
  ContextManager get contextManager => ContextManager(this);

  @override
  INyxx get client => MockNyxx();

  @override
  IInteractions get interactions => MockInteractions();
}

class MockButtonInteractionEvent with Mock implements IButtonInteractionEvent {
  @override
  final IButtonInteraction interaction;

  MockButtonInteractionEvent(String customId, Snowflake userId)
      : interaction = MockButtonInteraction(customId, MockUser(userId));
}

class MockButtonInteraction with Mock implements IButtonInteraction {
  @override
  final String customId;

  @override
  final IUser? userAuthor;

  MockButtonInteraction(this.customId, this.userAuthor);

  @override
  Cacheable<Snowflake, ITextChannel> get channel => MockCacheable(MockTextChannel());

  @override
  // ignore: hash_and_equals
  bool operator ==(dynamic other) => super == other;
}

class MockUser with Mock implements IUser {
  @override
  final Snowflake id;

  MockUser(this.id);

  @override
  // ignore: hash_and_equals
  bool operator ==(dynamic other) => super == other;
}

class MockCacheable<T extends SnowflakeEntity> with Mock implements Cacheable<Snowflake, T> {
  final T value;

  MockCacheable(this.value);

  @override
  T getOrDownload() => value;
}

class MockTextChannel with Mock implements ITextChannel {
  @override
  // ignore: hash_and_equals
  bool operator ==(dynamic other) => super == other;
}

class MockNyxx with Mock implements INyxxWebsocket {}

class MockInteractions with Mock implements IInteractions {}
