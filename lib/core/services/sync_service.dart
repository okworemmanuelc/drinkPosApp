import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/app_database.dart';
import '../database/daos.dart';

class SyncService {
  final SyncDao _syncDao;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;

  SyncService(this._syncDao) {
    _init();
  }

  void _init() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final items = await _syncDao.getPendingItems(limit: 50);
      for (final item in items) {
        // Check connectivity again before each item
        final connection = await _connectivity.checkConnectivity();
        if (connection.every((r) => r == ConnectivityResult.none)) break;

        await _syncItem(item);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _syncItem(SyncQueueData item) async {
    await _syncDao.markInProgress(item.id);

    try {
      // Mocking the API call logic
      // In a real app, you'd use a repository or API client here.
      // Based on actionType and payload, you would send data to the server.
      
      final response = await _mockApiCall(item.actionType, item.payload);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _syncDao.markDone(item.id);
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        // 4xx error: Client error, don't retry
        await _syncDao.markFailed(item.id, 'Client error: ${response.statusCode} - ${response.body}', permanent: true);
      } else {
        // 5xx or other error: Server error, retry
        await _syncDao.markFailed(item.id, 'Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Network timeout or other exceptions
      await _syncDao.markFailed(item.id, 'Network error: $e');
    }
  }

  // Temporary mock for demonstration
  Future<_MockResponse> _mockApiCall(String action, String payload) async {
    await Future.delayed(const Duration(seconds: 1));
    // For now, let's assume it always succeeds unless we implement real API logic
    return _MockResponse(200, 'Success');
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

class _MockResponse {
  final int statusCode;
  final String body;
  _MockResponse(this.statusCode, this.body);
}
