import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:test/test.dart';

void main() {
  group('EventManager with component events', () {
    test('completes with the correct event', () {
      final eventManager = EventManager(MockCommandsPlugin());

      final componentId = ComponentId.generate();
      final nextEventFuture = eventManager.nextButtonEvent(componentId);

      eventManager.processButtonInteraction(MockButtonInteractionEvent(
        componentId.toString(),
        Snowflake.zero,
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
        allowedUser: Snowflake.zero,
      );

      expect(
        () => eventManager.processButtonInteraction(MockButtonInteractionEvent(
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
        () => eventManager.processButtonInteraction(MockButtonInteractionEvent(
          componentId.toString(),
          Snowflake.zero,
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
}

class MockButtonInteractionEvent with Mock implements MessageComponentInteraction {
  MockButtonInteractionEvent(String customId, Snowflake userId)
      : data = MockMessageComponentInteractionData(customId),
        user = MockUser(userId);

  @override
  final MessageComponentInteractionData data;

  @override
  PartialChannel get channel => MockChannel();

  @override
  final User? user;

  @override
  InteractionManager get manager => MockInteractionManager();
}

class MockMessageComponentInteractionData with Mock implements MessageComponentInteractionData {
  @override
  final String customId;

  MockMessageComponentInteractionData(this.customId);
}

class MockUser with Mock implements User {
  @override
  final Snowflake id;

  MockUser(this.id);
}

class MockNyxx with Mock implements NyxxGateway {}

class MockChannel with Mock implements TextChannel {
  @override
  Future<TextChannel> get() async => this;
}

class MockInteractionManager with Mock implements InteractionManager {
  @override
  NyxxRest get client => MockNyxx();
}
