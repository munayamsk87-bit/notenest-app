/// Cloud sync is intentionally NOT faked (Spec §9).
///
/// NoteNest runs fully offline. This service is the seam where a real backend
/// (Firebase or Supabase) would be wired in. Until credentials are configured
/// it reports `isConfigured == false` and every call throws, so the UI can show
/// an honest "not configured" state instead of pretending sync is active.
class SyncNotConfiguredException implements Exception {
  const SyncNotConfiguredException();
  @override
  String toString() => 'Cloud sync is not configured.';
}

enum SyncStatus { localOnly, idle, syncing, error }

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Flip to true only after a real backend is wired in and credentials are
  /// present. Keep it false so the app never claims sync it can't perform.
  bool get isConfigured => false;

  SyncStatus get status =>
      isConfigured ? SyncStatus.idle : SyncStatus.localOnly;

  DateTime? get lastSyncedAt => null;

  Future<void> signInWithEmail(String email, String password) async {
    throw const SyncNotConfiguredException();
  }

  Future<void> signInWithGoogle() async {
    throw const SyncNotConfiguredException();
  }

  Future<void> signOut() async {
    throw const SyncNotConfiguredException();
  }

  /// Pushes local changes and pulls remote ones, detecting conflicts.
  Future<void> syncNow() async {
    throw const SyncNotConfiguredException();
  }
}
