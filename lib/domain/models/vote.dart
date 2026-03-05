/// Vote entity with idempotency and schema versioning support.
enum VoteStatus { pending, queued, submitted, confirmed, failed }

class Vote {
  final String voteUuid;
  final String buildingId;
  final String userId;
  final Map<String, dynamic> payload;
  final int schemaVersion;
  final DateTime createdAt;
  final VoteStatus status;

  const Vote({
    required this.voteUuid,
    required this.buildingId,
    required this.userId,
    required this.payload,
    required this.schemaVersion,
    required this.createdAt,
    this.status = VoteStatus.pending,
  });

  Vote copyWith({VoteStatus? status}) => Vote(
        voteUuid: voteUuid,
        buildingId: buildingId,
        userId: userId,
        payload: payload,
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      voteUuid: json['voteUuid'] as String,
      buildingId: json['buildingId'] as String,
      userId: json['userId'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      schemaVersion: json['schemaVersion'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: VoteStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => VoteStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'voteUuid': voteUuid,
        'buildingId': buildingId,
        'userId': userId,
        'payload': payload,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };
}
