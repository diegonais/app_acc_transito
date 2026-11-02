import 'authenticated_user.dart';

abstract interface class OnlineSessionContract {
  Stream<bool> get sessionChanges;
  Future<AuthenticatedUser?> restoreSession();
  Future<void> signOut();
}
