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

/// A class that wraps a Dart [Type], with additional support for subclass checking.
class DartType<T> {
  /// The [Type] represented by this [DartType].
  Type get internalType => T;

  /// Create a new [DartType];
  const DartType();

  /// Returns whether [other] was declared as a type that is a subtype of the type this [DartType]
  /// represents.
  bool isSupertypeOf<U>(DartType<U> other) => other is DartType<T>;

  /// Returns whether this [DartType] represents a type declared as a subtype of the type
  /// represented by [other].
  bool isSubtypeOf<U>(DartType<U> other) => other.isSupertypeOf(this);

  /// Returns whether [object] is a subtype of the type represented by this [DartType].
  ///
  /// This is similar to the `is` operator.
  bool isSuperClassOfObject(Object? object) => object is T;

  @override
  String toString() => T.toString();

  @override
  bool operator ==(Object? other) =>
      identical(this, other) || (other is DartType && other.internalType == internalType);

  @override
  int get hashCode => internalType.hashCode;
}
