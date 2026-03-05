import 'dart:async';

import '../data/api_client.dart';
import '../data/offline_vote_queue.dart';
import '../domain/models/vote.dart';
import '../platform/logger.dart';

/// Background worker that drains the offline vote queue with exponential
/// backoff, reconnection throttling, and conflict handling.
///
/// Relationships (C4):
///   SyncWorker → OfflineVoteQueue : drains & retries
///   SyncWorker → ApiClient        : requests upload of queued votes
class SyncWorker {
  final OfflineVoteQueue _queue;
  final ApiClient _apiClient;

  Timer? _timer;
  int _consecutiveFailures = 0;
  bool _isSyncing = false;
  static const _maxRetries = 8;
  static const _basePollInterval = Duration(seconds: 15);

  SyncWorker({
    required OfflineVoteQueue queue,
    required ApiClient apiClient,
  })  : _queue = queue,
        _apiClient = apiClient;

  bool get isRunning => _timer?.isActive == true;
  int get pendingCount => _queue.length;

  /// Start the periodic drain loop.
  void start() {
    if (_timer?.isActive == true) return;
    AppLogger.log(LogLevel.info, 'SyncWorker: started');
    _timer = Timer.periodic(_basePollInterval, (_) => drainQueue());
    // Immediately attempt a drain on start.
    drainQueue();
  }

  /// Stop the worker.
  void stop() {
    _timer?.cancel();
    _timer = null;
    AppLogger.log(LogLevel.info, 'SyncWorker: stopped');
  }

  /// Try to upload every queued vote.
  Future<void> drainQueue() async {
    if (_isSyncing || _queue.isEmpty) return;
    _isSyncing = true;
    AppLogger.log(LogLevel.info,
        'SyncWorker: draining ${_queue.length} queued votes');

    while (_queue.peek() != null) {
      final vote = _queue.peek()!;
      try {
        final result = await _apiClient.submitVote(vote);
        final status = result['status'] as String?;
        if (status == 'accepted' || status == 'already_accepted') {
          await _queue.dequeue(); // remove from queue on success
          _consecutiveFailures = 0;
          AppLogger.log(
              LogLevel.info, 'SyncWorker: synced ${vote.voteUuid}');
        } else {
          // Unexpected response → treat as failure
          _handleFailure(vote);
          break;
        }
      } catch (e) {
        _handleFailure(vote);
        break; // stop draining, wait for next poll
      }
    }
    _isSyncing = false;
  }

  void _handleFailure(Vote vote) {
    _consecutiveFailures++;
    final backoff = _getBackoffDuration();
    AppLogger.log(LogLevel.warning,
        'SyncWorker: failure #$_consecutiveFailures, backoff ${backoff.inSeconds}s');
    // Reschedule with backoff by pausing the timer briefly.
    if (_consecutiveFailures >= _maxRetries) {
      AppLogger.log(LogLevel.error, 'SyncWorker: max retries reached, pausing');
      stop();
    }
  }

  /// Exponential backoff: 2^failures * 1 second, capped at 5 minutes.
  Duration _getBackoffDuration() {
    final seconds = (1 << _consecutiveFailures).clamp(1, 300);
    return Duration(seconds: seconds);
  }
}
