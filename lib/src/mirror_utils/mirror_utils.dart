// Will not work yet; see https://github.com/dart-lang/sdk/issues/48057
// Comment out `with_mirrors.dart` import manually to test
export 'compiled.dart' if (dart.library.mirrors) 'with_mirrors.dart';
export 'function_data.dart';
export 'type_data.dart';
