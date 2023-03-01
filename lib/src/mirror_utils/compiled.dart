import '../errors.dart';
import '../util/util.dart';
import 'mirror_utils.dart';

Map<dynamic, FunctionData>? _functionData;

FunctionData loadFunctionData(Function fn) {
  if (_functionData == null) {
    throw CommandsError(
      'Function data was not correctly loaded. Did you compile the wrong file?'
      '\nSee https://pub.dev/packages/nyxx_commands#compiling-nyxx-commands for more information.',
    );
  }

  dynamic id = idMap[fn];

  FunctionData? result = _functionData![id];

  if (result == null) {
    throw CommandsException(
      "Couldn't load function data for function $fn"
      '\nSee https://pub.dev/packages/nyxx_commands#compiling-nyxx-commands for more information.',
    );
  }

  return result;
}

void loadData(Map<dynamic, FunctionData> functionData) {
  _functionData = functionData;
}
