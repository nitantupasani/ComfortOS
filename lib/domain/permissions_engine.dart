import 'models/user.dart';
import 'models/building.dart';

/// Pure domain component – role-based and tenant-scoped permission checks.
///
/// Relationships (C4):
///   UI → PermissionsEngine : checks permissions via in-process calls
class PermissionsEngine {
  /// Whether [user] may cast comfort votes in [building].
  bool canVote(User user, Building building) {
    if (!_sameTenant(user, building)) return false;
    // All authenticated users in the same tenant may vote.
    return true;
  }

  /// Whether [user] has management privileges on [building].
  bool canManageBuilding(User user, Building building) {
    if (!_sameTenant(user, building)) return false;
    return user.role == UserRole.manager || user.role == UserRole.admin;
  }

  /// Shorthand admin check.
  bool isAdmin(User user) => user.role == UserRole.admin;

  /// Tenant isolation – the fundamental multi-tenant guard.
  bool _sameTenant(User user, Building building) {
    return user.tenantId == building.tenantId;
  }

  /// Validate that the user's claims contain the required scope.
  bool hasScope(User user, String scope) {
    final scopes = user.claims['scopes'] as List<dynamic>? ?? [];
    return scopes.contains(scope);
  }
}
