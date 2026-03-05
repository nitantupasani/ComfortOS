import 'package:flutter_test/flutter_test.dart';

import 'package:comfortos/domain/vote_domain.dart';
import 'package:comfortos/domain/permissions_engine.dart';
import 'package:comfortos/domain/models/user.dart';
import 'package:comfortos/domain/models/building.dart';
import 'package:comfortos/domain/models/vote.dart';

void main() {
  group('VoteDomain', () {
    late VoteDomain voteDomain;

    setUp(() => voteDomain = VoteDomain());

    test('createVote generates a valid vote with UUID', () {
      final vote = voteDomain.createVote(
        buildingId: 'bldg-001',
        userId: 'usr-001',
        payload: {'thermal_comfort': 5},
        schemaVersion: 1,
      );
      expect(vote.voteUuid, isNotEmpty);
      expect(vote.buildingId, 'bldg-001');
      expect(vote.status, VoteStatus.pending);
    });

    test('checkIdempotency prevents duplicate submission', () {
      final vote = voteDomain.createVote(
        buildingId: 'bldg-001',
        userId: 'usr-001',
        payload: {'thermal_comfort': 4},
        schemaVersion: 1,
      );
      expect(voteDomain.checkIdempotency(vote), isTrue);
      voteDomain.markSubmitted(vote);
      expect(voteDomain.checkIdempotency(vote), isFalse);
    });
  });

  group('PermissionsEngine', () {
    final engine = PermissionsEngine();
    const user = User(
      id: 'usr-001',
      email: 'a@b.com',
      name: 'Alice',
      role: UserRole.occupant,
      tenantId: 'tenant-acme',
    );
    const building = Building(
      id: 'bldg-001',
      name: 'HQ',
      address: '123 Main',
      tenantId: 'tenant-acme',
    );
    const otherBuilding = Building(
      id: 'bldg-other',
      name: 'Other',
      address: '456 Elm',
      tenantId: 'tenant-other',
    );

    test('occupant can vote in same-tenant building', () {
      expect(engine.canVote(user, building), isTrue);
    });

    test('occupant cannot vote in other tenant building', () {
      expect(engine.canVote(user, otherBuilding), isFalse);
    });

    test('occupant cannot manage building', () {
      expect(engine.canManageBuilding(user, building), isFalse);
    });

    test('manager can manage building', () {
      final mgr = User(
        id: 'usr-002',
        email: 'b@b.com',
        name: 'Bob',
        role: UserRole.manager,
        tenantId: 'tenant-acme',
      );
      expect(engine.canManageBuilding(mgr, building), isTrue);
    });
  });
}
