/// Single owner of the `app_links` subscription for `reebaplus://invite?token=…`.
///
/// Why this needs its own owner: supabase_flutter already subscribes to
/// `reebaplus://login-callback` via its own deep-link handler for OAuth.
/// A second naive listener that doesn't filter by `uri.host` would race
/// with that subscription. This router only forwards URIs whose host is
/// exactly `invite` and which carry a non-empty `token` query param;
/// everything else is left for Supabase / future handlers.
///
/// Routing decisions live in the app shell ([_ReebaplusPosAppState]),
/// which watches `pendingUri` and pushes [InviteLandingScreen] on the
/// current navigator. The router never holds the navigator key directly —
/// the app regenerates that key on auth changes, so a held reference
/// would go stale.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class InviteLinkRouter {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Latest unconsumed invite URI. Transitions non-null when a deep link
  /// arrives; drain via [consume]. The app watches this notifier and
  /// pushes the landing screen on transition.
  final ValueNotifier<Uri?> pendingUri = ValueNotifier(null);

  /// Subscribe to warm-start URIs. Idempotent.
  void start() {
    _sub ??= _appLinks.uriLinkStream.listen(_dispatch, onError: (_) {});
  }

  /// Drain the cold-start URI, if any. Call once during app boot after
  /// Supabase is ready.
  Future<void> handleColdStart() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _dispatch(uri);
    } catch (_) {
      // No initial link / native channel unavailable — ignore.
    }
  }

  void _dispatch(Uri uri) {
    final isInvite = uri.host == 'invite' &&
        (uri.queryParameters['token']?.isNotEmpty ?? false);
    if (!isInvite) return;
    pendingUri.value = uri;
  }

  /// Returns the pending URI and clears the notifier in one step.
  Uri? consume() {
    final v = pendingUri.value;
    pendingUri.value = null;
    return v;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    pendingUri.dispose();
  }
}
