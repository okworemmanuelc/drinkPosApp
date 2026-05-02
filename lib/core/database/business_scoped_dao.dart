import 'package:drift/drift.dart';

import 'package:reebaplus_pos/core/database/app_database.dart';

/// Mixin for DAOs that touch tenant-scoped tables. Provides a single read
/// path to the current session's businessId, sourced from
/// [AppDatabase.businessIdResolver] (set by AuthService at login).
///
/// Mix in alongside Drift's generated `_$XxxDaoMixin`. Methods that read or
/// write tenant data should call [requireBusinessId] and add the value as a
/// `WHERE` filter (or as a column on insert).
mixin BusinessScopedDao<DB extends GeneratedDatabase> on DatabaseAccessor<DB> {
  AppDatabase get _appDb => attachedDatabase as AppDatabase;
  String? get currentBusinessId => _appDb.currentBusinessId;

  /// Returns the current businessId, throwing if no session is active.
  /// Use at every tenant-scoped query site so cross-tenant leaks become
  /// loud failures instead of silent data bleed.
  String requireBusinessId() {
    final id = currentBusinessId;
    if (id == null) {
      throw StateError(
        'No current business — DAO query attempted outside an authenticated session',
      );
    }
    return id;
  }

  /// Helper to standardize tenant filtering in queries.
  /// Usage: `..where((t) => whereBusiness(t))`
  Expression<bool> whereBusiness(dynamic table) {
    // Businesses table uses 'id' as its tenant identifier.
    if (table.actualTableName == 'businesses') {
      return (table.id as Expression<String>).equals(requireBusinessId());
    }
    return (table.businessId as Expression<String>).equals(requireBusinessId());
  }
}
