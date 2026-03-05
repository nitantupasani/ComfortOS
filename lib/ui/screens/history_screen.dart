import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../widgets/bottom_nav_bar.dart';

/// Vote history screen — shows past comfort votes.
///
/// Accessible via the bottom navigation "History" tab.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(authStateProvider).user;
      if (user != null) {
        ref.read(voteStateProvider.notifier).loadHistory(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final votes = ref.watch(voteStateProvider).history;
    final queueCount =
        ref.read(voteStateProvider.notifier).offlinePendingCount;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'Vote History',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: -0.3,
                ),
              ),
            ),

            // ── Offline queue badge ──
            if (queueCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off,
                          size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text('$queueCount vote(s) queued offline',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.blue)),
                    ],
                  ),
                ),
              ),

            // ── Vote list ──
            Expanded(
              child: votes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.how_to_vote,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No votes yet',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[500])),
                          const SizedBox(height: 4),
                          Text(
                            'Your comfort votes will appear here.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: votes.length,
                      separatorBuilder: (_, unused) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final vote = votes[i];
                        final statusColor = vote.status.name == 'confirmed' ||
                                vote.status.name == 'submitted'
                            ? Colors.green
                            : Colors.orange;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.how_to_vote,
                                    size: 20, color: statusColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vote ${vote.voteUuid.substring(0, 8)}…',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      vote.createdAt
                                          .toLocal()
                                          .toString()
                                          .substring(0, 16),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  vote.status.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // ── Bottom nav ──
            const AppBottomNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }
}
