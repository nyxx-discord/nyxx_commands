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

import 'package:nyxx/nyxx.dart';

import 'checks.dart';

/// A check that checks that a command was executed by a specific user.
class UserCheck extends Check {
  /// The IDs of the users this check allows.
  Iterable<Snowflake> userIds;

  /// Create a new [UserCheck] that succeeds if the context was created by [user].
  ///
  /// You might also be interested in:
  /// - [UserCheck.id], for creating this same check without an instance of [IUser],
  /// - [UserCheck.any], for checking that a context was created by a user in a set or users.
  UserCheck(IUser user, [String? name]) : this.id(user.id, name);

  /// Create a new [UserCheck] that succeeds if the ID of the user that created the context is [id].
  UserCheck.id(Snowflake id, [String? name])
      : userIds = [id],
        super((context) => context.user.id == id, name ?? 'User Check on $id');

  /// Create a new [UserCheck] that succeeds if the context was created by any one of [users].
  ///
  /// You might also be interested in:
  /// - [UserCheck.anyId], for creating this same check without instance of [IUser].
  UserCheck.any(Iterable<IUser> users, [String? name])
      : this.anyId(users.map((user) => user.id), name);

  /// Create a new [UserCheck] that succeeds if the ID of the user that created the context is in
  /// [ids].
  UserCheck.anyId(Iterable<Snowflake> ids, [String? name])
      : userIds = ids,
        super(
          (context) => ids.contains(context.user.id),
          name ?? 'User Check on any of [${ids.join(', ')}]',
        );
}

/// A check that checks that the user that executes a command has a specific role.
class RoleCheck extends Check {
  /// The IDs of the roles this check allows.
  Iterable<Snowflake> roleIds;

  /// Create a new [RoleCheck] that succeeds if the user that created the context has [role].
  ///
  /// You might also be interested in:
  /// - [RoleCheck.id], for creating this same check without an instance of [IRole];
  /// - [RoleCheck.any], for checking that the user that created a context has one of a set or
  ///   roles.
  RoleCheck(IRole role, [String? name]) : this.id(role.id, name);

  /// Create a new [RoleCheck] that succeeds if the user that created the context has a role with
  /// the id [id].
  RoleCheck.id(Snowflake id, [String? name])
      : roleIds = [id],
        super(
          (context) => context.member?.roles.any((role) => role.id == id) ?? false,
          name ?? 'Role Check on $id',
        );

  /// Create a new [RoleCheck] that succeeds if the user that created the context has any of [roles].
  ///
  /// You might also be interested in:
  /// - [RoleCheck.anyId], for creating this same check without instances of [IRole].
  RoleCheck.any(Iterable<IRole> roles, [String? name])
      : this.anyId(roles.map((role) => role.id), name);

  /// Create a new [RoleCheck] that succeeds if the user that created the context has any role for
  /// which the role's id is in [roles].
  RoleCheck.anyId(Iterable<Snowflake> roles, [String? name])
      : roleIds = roles,
        super(
          (context) => context.member?.roles.any((role) => roles.contains(role.id)) ?? false,
          name ?? 'Role Check on any of [${roles.join(', ')}]',
        );
}
