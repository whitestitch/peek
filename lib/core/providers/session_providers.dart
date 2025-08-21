import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/core/session_manager.dart';

/// Provider for SessionManager instance
final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager();
});

/// Provider for current session state
final sessionStateProvider = StateProvider<String>((ref) {
  return 'idle';
});

/// Provider for current request ID
final sessionRequestIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// Provider for whether user is currently in a session
final isInSessionProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provider for whether user can receive peek requests
final canReceivePeeksProvider = StateProvider<bool>((ref) {
  return true;
});

/// Provider for session info (for debugging)
final sessionInfoProvider = Provider<Map<String, dynamic>>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.getSessionInfo();
});
