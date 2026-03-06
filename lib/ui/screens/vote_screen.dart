import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../sdui/default_vote_form.dart';
import '../widgets/vote_form_widget.dart';

/// Comfort vote screen — SDUI-driven vote form matching the screen1dart design.
///
/// Clean card layout with thermal comfort scale, thermal preference,
/// air quality multi-select, wrapped in a scrollable form.
class VoteScreen extends ConsumerWidget {
  const VoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final presence = ref.watch(presenceStateProvider);
    final voteState = ref.watch(voteStateProvider);
    final building = presence.activeBuilding;
    final user = auth.user;

    if (building == null || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vote')),
        body: const Center(child: Text('Select a building first.')),
      );
    }

    // Permission check
    final perms = ref.read(permissionsEngineProvider);
    if (!perms.canVote(user, building)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vote')),
        body: const Center(
          child: Text('You do not have permission to vote in this building.'),
        ),
      );
    }

    final formConfigAsync = ref.watch(voteFormConfigProvider(building.id));
    final configGov = ref.read(configGovernanceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar with back button ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => context.go('/dashboard'),
                  ),
                  Expanded(
                    child: Text(
                      'Comfort Vote',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance the back button
                ],
              ),
            ),

            // ── Scrollable form content ──
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.green.shade50],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: formConfigAsync.when(
                        loading: () => const Center(
                            child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        )),
                        error: (e, _) => Text('Could not load form: $e'),
                        data: (formSchema) {
                          // Use server schema, or the rich default
                          final schema = formSchema ?? DefaultVoteForm.config;
                          return VoteFormWidget(
                            formSchema: schema,
                            onSubmit: (payload) async {
                              await ref
                                  .read(voteStateProvider.notifier)
                                  .submitVote(
                                    buildingId: building.id,
                                    userId: user.id,
                                    payload: payload,
                                    schemaVersion:
                                        configGov.currentSchemaVersion,
                                  );
                              if (context.mounted) {
                                final result = ref
                                        .read(voteStateProvider)
                                        .lastResult ??
                                    'unknown';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_resultMessage(result)),
                                    backgroundColor: result == 'accepted'
                                        ? Colors.green
                                        : null,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                                if (result == 'accepted') {
                                  context.go('/comfort');
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Submission indicator ──
            if (voteState.isSubmitting)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  String _resultMessage(String result) {
    switch (result) {
      case 'accepted':
        return 'Vote submitted successfully!';
      case 'already_accepted':
        return 'Vote was already recorded.';
      case 'queued':
        return 'Vote queued — will submit when online.';
      case 'duplicate':
        return 'Duplicate vote detected.';
      default:
        return 'Vote result: $result';
    }
  }
}
