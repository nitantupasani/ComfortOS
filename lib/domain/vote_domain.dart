import 'package:uuid/uuid.dart';

import 'models/vote.dart';

/// Pure domain logic for vote creation, validation, and idempotency.
///
/// Relationships (C4):
///   UI → VoteDomain : creates vote payload
class VoteDomain {
  static const _uuid = Uuid();

  /// Tracked UUIDs for local idempotency enforcement.
  final Set<String> _submittedUuids = {};

  /// Create a validated vote payload with a fresh UUID and schema tag.
  Vote createVote({
    required String buildingId,
    required String userId,
    required Map<String, dynamic> payload,
    required int schemaVersion,
  }) {
    final vote = Vote(
      voteUuid: _uuid.v4(),
      buildingId: buildingId,
      userId: userId,
      payload: payload,
      schemaVersion: schemaVersion,
      createdAt: DateTime.now(),
      status: VoteStatus.pending,
    );

    if (!validateVote(vote)) {
      throw ArgumentError('Invalid vote payload');
    }

    return vote;
  }

  /// Validates required fields and payload structure.
  bool validateVote(Vote vote) {
    if (vote.buildingId.isEmpty) return false;
    if (vote.userId.isEmpty) return false;
    if (vote.payload.isEmpty) return false;
    if (vote.schemaVersion < 1) return false;
    return true;
  }

  /// Returns true if this UUID was NOT previously submitted (i.e. safe to send).
  bool checkIdempotency(Vote vote) {
    return !_submittedUuids.contains(vote.voteUuid);
  }

  /// Mark a vote UUID as submitted.
  void markSubmitted(Vote vote) {
    _submittedUuids.add(vote.voteUuid);
  }

  /// Generate a fresh v4 UUID.
  String generateUuid() => _uuid.v4();
}
