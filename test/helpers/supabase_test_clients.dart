import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_test_env.dart';

/// Holds two SupabaseClients for Tier-2 integration tests:
///
///   * [userClient]  — anon key, signed-in as the test user. Use this to
///                     invoke RPCs (the tenant guard in v2 RPCs reads
///                     auth.uid(), so a service-role client can't legally
///                     call them — auth.uid() returns NULL there).
///   * [adminClient] — service-role key. Bypasses RLS. Use this for setup,
///                     teardown, and "did the row land?" verification.
///
/// Construct via [setUp] and dispose via [dispose].
class TestClients {
  final SupabaseClient userClient;
  final SupabaseClient adminClient;
  final TestEnv env;

  TestClients._(this.userClient, this.adminClient, this.env);

  static Future<TestClients> setUp() async {
    final env = TestEnv.load();

    final user = SupabaseClient(env.url, env.anonKey);
    final admin = SupabaseClient(env.url, env.serviceRoleKey);

    // Restore the test user's session from the persisted refresh token.
    // setSession exchanges the refresh token for a fresh access token, so
    // subsequent rpc() / from() calls carry the test user's auth.uid().
    await user.auth.setSession(env.userRefreshToken);
    if (user.auth.currentUser == null) {
      throw StateError(
        'TEST_USER_REFRESH_TOKEN failed to authenticate. The token may '
        'have expired (default 30 days). Re-OTP the test user and update '
        'the env var. See test/integration/README.md.',
      );
    }

    return TestClients._(user, admin, env);
  }

  Future<void> dispose() async {
    await userClient.dispose();
    await adminClient.dispose();
  }
}
