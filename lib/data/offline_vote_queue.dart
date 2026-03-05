import '../domain/models/vote.dart';
import '../platform/logger.dart';
import 'encrypted_local_storage.dart';

/// Local encrypted queue for offline vote persistence, deduplication, and
/// integrity checking.
///
/// Relationships (C4):
///   OfflineVoteQueue → EncryptedLocalStorage : persists queued votes
///   SyncWorker       → OfflineVoteQueue      : drains & retries
///   ApiClient        → OfflineVoteQueue      : enqueues on network failure
class OfflineVoteQueue {
  final EncryptedLocalStorage _storage;
  final List<Vote> _queue = [];

  static const _storageKey = 'offline_vote_queue';

  OfflineVoteQueue(this._storage);

  // ── Queue operations ──────────────────────────────────────────────────

  Future<void> enqueue(Vote vote) async {
    // Deduplication guard – skip if same UUID already queued.
    if (_queue.any((v) => v.voteUuid == vote.voteUuid)) {
      AppLogger.log(LogLevel.warning,
          'OfflineVoteQueue: duplicate UUID ${vote.voteUuid} skipped');
      return;
    }
    _queue.add(vote.copyWith(status: VoteStatus.queued));
    await _persist();
    AppLogger.log(
        LogLevel.info, 'OfflineVoteQueue: enqueued ${vote.voteUuid}');
  }

  Future<Vote?> dequeue() async {
    if (_queue.isEmpty) return null;
    final vote = _queue.removeAt(0);
    await _persist();
    return vote;
  }

  Vote? peek() => _queue.isEmpty ? null : _queue.first;

  bool get isEmpty => _queue.isEmpty;
  int get length => _queue.length;

  List<Vote> get pending => List.unmodifiable(_queue);

  // ── Deduplication pass ────────────────────────────────────────────────

  Future<void> deduplicate() async {
    final seen = <String>{};
    _queue.removeWhere((v) => !seen.add(v.voteUuid));
    await _persist();
  }

  // ── Integrity check ──────────────────────────────────────────────────

  Future<bool> integrityCheck() async {
    for (final vote in _queue) {
      if (vote.voteUuid.isEmpty || vote.buildingId.isEmpty) {
        AppLogger.log(LogLevel.error,
            'OfflineVoteQueue: integrity failure for ${vote.voteUuid}');
        return false;
      }
    }
    return true;
  }

  // ── Persistence ───────────────────────────────────────────────────────

  Future<void> _persist() async {
    final data = _queue.map((v) => v.toJson()).toList();
    await _storage.cacheList(_storageKey, data);
  }

  /// Restore queue from encrypted local storage on app start.
  Future<void> restore() async {
    try {
      final data = await _storage.getCachedList(_storageKey);
      _queue
        ..clear()
        ..addAll(data.map((m) => Vote.fromJson(m)));
      AppLogger.log(
          LogLevel.info, 'OfflineVoteQueue: restored ${_queue.length} votes');
    } catch (e, st) {
      AppLogger.reportCrash(e, st);
    }
  }
}
