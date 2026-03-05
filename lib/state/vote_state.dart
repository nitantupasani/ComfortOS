import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/vote.dart';
import '../domain/vote_domain.dart';
import '../data/api_client.dart';
import '../data/offline_vote_queue.dart';
import '../platform/logger.dart';

/// Vote submission + history state.
class VoteState {
  final List<Vote> history;
  final bool isSubmitting;
  final String? lastResult; // 'accepted', 'queued', 'failed'
  final String? error;

  const VoteState({
    this.history = const [],
    this.isSubmitting = false,
    this.lastResult,
    this.error,
  });

  VoteState copyWith({
    List<Vote>? history,
    bool? isSubmitting,
    String? lastResult,
    String? error,
  }) =>
      VoteState(
        history: history ?? this.history,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        lastResult: lastResult,
        error: error,
      );
}

/// Notifier for vote creation, submission, and history.
///
/// Relationships (C4):
///   UI → VoteDomain : creates vote payload
///   UI → AppStateStore : reads/writes
///   ApiClient → OfflineVoteQueue : on network failure enqueue
class VoteNotifier extends StateNotifier<VoteState> {
  final VoteDomain _voteDomain;
  final ApiClient _apiClient;
  final OfflineVoteQueue _offlineQueue;

  VoteNotifier({
    required VoteDomain voteDomain,
    required ApiClient apiClient,
    required OfflineVoteQueue offlineQueue,
  })  : _voteDomain = voteDomain,
        _apiClient = apiClient,
        _offlineQueue = offlineQueue,
        super(const VoteState());

  /// Create and submit a comfort vote.
  Future<void> submitVote({
    required String buildingId,
    required String userId,
    required Map<String, dynamic> payload,
    required int schemaVersion,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, lastResult: null);
    try {
      final vote = _voteDomain.createVote(
        buildingId: buildingId,
        userId: userId,
        payload: payload,
        schemaVersion: schemaVersion,
      );

      // Idempotency check
      if (!_voteDomain.checkIdempotency(vote)) {
        state = state.copyWith(
          isSubmitting: false,
          lastResult: 'duplicate',
        );
        return;
      }

      final result = await _apiClient.submitVote(vote);
      _voteDomain.markSubmitted(vote);

      final status = result['status'] as String? ?? 'unknown';
      state = state.copyWith(isSubmitting: false, lastResult: status);

      AppLogger.telemetry('vote_submitted', properties: {
        'buildingId': buildingId,
        'status': status,
      });
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        lastResult: 'failed',
        error: e.toString(),
      );
      AppLogger.log(LogLevel.error, 'Vote submission failed: $e');
    }
  }

  /// Load vote history from backend.
  Future<void> loadHistory(String userId) async {
    try {
      final data = await _apiClient.getVoteHistory(userId);
      final votes = data.map((m) => Vote.fromJson(m)).toList();
      state = state.copyWith(history: votes);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Count of votes pending in offline queue.
  int get offlinePendingCount => _offlineQueue.length;
}
