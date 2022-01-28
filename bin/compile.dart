import 'package:logging/logging.dart';

import 'compile/generator.dart';

void main(List<String> args) {
  Logger.root.onRecord.listen((LogRecord rec) {
    print("[${rec.time}] [${rec.level.name}] ${rec.message}");
  });

  generate(args.first, 'out.g.dart');
}
