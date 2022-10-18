import 'package:nyxx_commands/nyxx_commands.dart';

import '../util/util.dart';
import 'mirror_utils.dart';

Map<dynamic, FunctionData>? _functionData;

FunctionData loadFunctionData(Function fn) {
  if (_functionData == null) {
    throw CommandsError('Function data was not correctly loaded. Did you compile the wrong file?');
  }

  dynamic id = idMap[fn];

  FunctionData? result = _functionData![id];

  if (result == null) {
    throw CommandsException("Couldn't load function data for function $fn");
  }

  return result;
}

void loadData(Map<dynamic, FunctionData> functionData) {
  _functionData = functionData;
}
