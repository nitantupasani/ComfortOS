import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/encrypted_local_storage.dart';
import 'platform/logger.dart';
import 'state/providers.dart';

/// Application entry point.
///
/// Initialisation sequence:
///   1. Bind Flutter framework
///   2. Initialise Hive (Encrypted Local Storage)
///   3. Restore offline vote queue from storage
///   4. Install global error handlers (Logging + Error Boundary)
///   5. Launch ProviderScope → ComfortOSApp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Initialise encrypted local storage (Hive) ────────────────────
  await Hive.initFlutter();
  final storage = EncryptedLocalStorage();
  await storage.init();

  AppLogger.log(LogLevel.info, 'Storage initialised');

  // ── 2. Install global error handlers ────────────────────────────────
  FlutterError.onError = (details) {
    AppLogger.reportCrash(details.exception, details.stack ?? StackTrace.empty);
  };

  // ── 3. Run app with Riverpod ProviderScope ──────────────────────────
  runApp(
    ProviderScope(
      overrides: [
        // Provide the pre-initialised storage instance.
        encryptedLocalStorageProvider.overrideWithValue(storage),
      ],
      child: const _AppBootstrap(),
    ),
  );
}

/// Tiny wrapper that restores persisted state before showing the real app.
class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Restore offline vote queue
    await ref.read(offlineVoteQueueProvider).restore();
    // Restore config schema version
    await ref.read(configGovernanceProvider).restoreVersion();
    // Try to restore auth session
    await ref.read(authStateProvider.notifier).tryRestore();

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return const ComfortOSApp();
  }
}
