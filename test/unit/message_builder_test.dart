import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/util/util.dart';
import 'package:test/test.dart';

void main() => group("MessageCreateUpdateBuilder", () {
  test("copies flags correctly", () {
    final builder1 = MessageBuilder(flags: MessageFlags.isComponentsV2);
    expect(builder1.flags?.contains(MessageFlags.isComponentsV2), isTrue, reason: "Flags were not applied");
    final builder2 = MessageCreateUpdateBuilder.fromMessageBuilder(builder1);
    expect(builder2.flags?.contains(MessageFlags.isComponentsV2), isTrue, reason: "Flags were not copied");
  });
});