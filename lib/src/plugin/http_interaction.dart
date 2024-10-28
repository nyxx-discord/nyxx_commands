import 'package:nyxx/nyxx.dart';

import 'package:nyxx/src/utils/iterable_extension.dart';

abstract class HttpInteractionsPlugin extends NyxxPlugin<NyxxRest> {
  Stream<Interaction<dynamic>> get onInteractionCreate;

  /// A [Stream] of [ApplicationCommandInteraction]s received by this client.
  Stream<ApplicationCommandInteraction> get onApplicationCommandInteraction =>
      onInteractionCreate.whereType<ApplicationCommandInteraction>();

  /// A [Stream] of [MessageComponentInteraction]s received by this client.
  Stream<MessageComponentInteraction> get onMessageComponentInteraction =>
      onInteractionCreate.whereType<MessageComponentInteraction>();

  /// A [Stream] of [ModalSubmitInteraction]s received by this client.
  Stream<ModalSubmitInteraction> get onModalSubmitInteraction =>
      onInteractionCreate.whereType<ModalSubmitInteraction>();

  /// A [Stream] of [ApplicationCommandAutocompleteInteraction]s received by this client.
  Stream<ApplicationCommandAutocompleteInteraction>
      get onApplicationCommandAutocompleteInteraction =>
          onInteractionCreate.whereType<ApplicationCommandAutocompleteInteraction>();
}
