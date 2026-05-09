import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

/// Captures a refresh token for the Tier-2 integration tests by signing in
/// the test user via OTP.
///
/// Pre-reqs: TEST_SUPABASE_URL and TEST_SUPABASE_ANON_KEY exported.
///
///   # Step 1: send the OTP
///   dart run tool/capture_test_refresh_token.dart send test+sync@example.com
///
///   # Step 2: paste the 6-digit code from the email
///   dart run tool/capture_test_refresh_token.dart verify test+sync@example.com 123456
///
/// On success, prints `TEST_USER_REFRESH_TOKEN=...` — paste that line into
/// your `.envrc`.
Future<void> main(List<String> args) async {
  final url = Platform.environment['TEST_SUPABASE_URL'];
  final anonKey = Platform.environment['TEST_SUPABASE_ANON_KEY'];
  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    stderr.writeln(
      'Set TEST_SUPABASE_URL and TEST_SUPABASE_ANON_KEY before running this '
      'script. See test/integration/README.md.',
    );
    exit(64);
  }

  if (args.length < 2) {
    stderr.writeln('Usage:');
    stderr.writeln(
      '  dart run tool/capture_test_refresh_token.dart send <email>',
    );
    stderr.writeln(
      '  dart run tool/capture_test_refresh_token.dart verify <email> <code>',
    );
    exit(64);
  }

  final mode = args[0];
  final email = args[1];
  // Force implicit flow — PKCE needs persistent storage, which we don't have
  // in a one-shot CLI script. Implicit returns the session straight from
  // verifyOTP, which is exactly what we want.
  final client = SupabaseClient(
    url,
    anonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  try {
    switch (mode) {
      case 'send':
        await client.auth.signInWithOtp(email: email);
        stdout.writeln('OTP sent to $email. Check the inbox, then re-run:');
        stdout.writeln(
          '  dart run tool/capture_test_refresh_token.dart verify $email <6-digit code>',
        );
        break;
      case 'verify':
        if (args.length < 3) {
          stderr.writeln('verify requires a 6-digit code as the third arg.');
          exit(64);
        }
        final res = await client.auth.verifyOTP(
          email: email,
          token: args[2],
          type: OtpType.email,
        );
        final token = res.session?.refreshToken;
        if (token == null || token.isEmpty) {
          stderr.writeln('OTP verified but no refresh token was returned.');
          exit(1);
        }
        stdout.writeln('TEST_USER_REFRESH_TOKEN=$token');
        break;
      default:
        stderr.writeln('Unknown mode: $mode (expected `send` or `verify`)');
        exit(64);
    }
  } finally {
    await client.dispose();
  }
}
