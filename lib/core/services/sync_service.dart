// Stub sync service — no Drift, no network calls.

class SyncService {
  SyncService() {
    _init();
  }

  void _init() {}

  Future<void> processQueue() async {}

  void dispose() {}
}
