//  Copyright 2021 Abitofevrything and others.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

// Will not work yet; see https://github.com/dart-lang/sdk/issues/48057
// Comment out `with_mirrors.dart` import manually to test
export 'compiled.dart' if (dart.library.mirrors) 'with_mirrors.dart';
export 'function_data.dart';
export 'type_data.dart';
