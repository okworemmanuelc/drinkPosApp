import 'dart:io';

/// Reads the env vars Tier-2 (real-Supabase) integration tests need.
/// Throws a clear, single message listing every missing var so devs aren't
/// debugging null-deref errors. See test/integration/README.md for setup.
class TestEnv {
  final String url;
  final String anonKey;
  final String serviceRoleKey;
  final String userRefreshToken;
  final String businessId;
  final String userId;

  TestEnv._({
    required this.url,
    required this.anonKey,
    required this.serviceRoleKey,
    required this.userRefreshToken,
    required this.businessId,
    required this.userId,
  });

  static TestEnv load() {
    final env = Platform.environment;
    final missing = <String>[];
    String require(String key) {
      final v = env[key];
      if (v == null || v.isEmpty) {
        missing.add(key);
        return '';
      }
      return v;
    }

    final url = require('TEST_SUPABASE_URL');
    final anonKey = require('TEST_SUPABASE_ANON_KEY');
    final serviceRoleKey = require('TEST_SUPABASE_SERVICE_ROLE_KEY');
    final refreshToken = require('TEST_USER_REFRESH_TOKEN');
    final businessId = require('TEST_BUSINESS_ID');
    final userId = require('TEST_USER_ID');

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required env var(s) for Tier-2 integration tests: '
        '${missing.join(", ")}. '
        'See test/integration/README.md for one-time setup.',
      );
    }

    return TestEnv._(
      url: url,
      anonKey: anonKey,
      serviceRoleKey: serviceRoleKey,
      userRefreshToken: refreshToken,
      businessId: businessId,
      userId: userId,
    );
  }
}
