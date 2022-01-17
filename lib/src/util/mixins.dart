import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands/interfaces.dart';
import 'package:nyxx_commands/src/commands/options.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/errors.dart';

mixin ParentMixin<T extends IContext> implements ICommandRegisterable<T> {
  ICommandGroup<IContext>? _parent;

  @override
  ICommandGroup<IContext>? get parent => _parent;

  @override
  set parent(ICommandGroup<IContext>? parent) {
    if (_parent != null) {
      throw CommandRegistrationError('Cannot register command "$name" again');
    }
  }
}

mixin CheckMixin<T extends IContext> on ICommandRegisterable<T> implements IChecked {
  final List<AbstractCheck> _checks = [];

  @override
  Iterable<AbstractCheck> get checks => [...?parent?.checks, ..._checks];

  @override
  void check(AbstractCheck check) {
    _checks.add(check);

    for (final preCallHook in check.preCallHooks) {
      onPreCall.listen(preCallHook);
    }

    for (final postCallHook in check.postCallHooks) {
      onPostCall.listen(postCallHook);
    }
  }
}

mixin OptionsMixin<T extends IContext> on ICommandRegisterable<T> implements IOptions {
  CommandOptions get _options;

  @override
  CommandOptions get options {
    if (parent == null) {
      return _options;
    }

    CommandOptions parentOptions = parent!.options;

    return CommandOptions(
      autoAcknowledgeInteractions:
          _options.autoAcknowledgeInteractions ?? parentOptions.autoAcknowledgeInteractions,
      acceptBotCommands: _options.acceptBotCommands ?? parentOptions.acceptBotCommands,
      acceptSelfCommands: _options.acceptSelfCommands ?? parentOptions.acceptSelfCommands,
      hideOriginalResponse: _options.hideOriginalResponse ?? parentOptions.hideOriginalResponse,
    );
  }
}
