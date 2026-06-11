/// Routes a notification's `action_url` to a safe destination given the
/// current user's role.
///
/// Notifications can carry staff-flavoured deep links (e.g.
/// `/children/abc`) that the GoRouter redirect guard will bounce parents
/// away from. Rather than triggering a silent guard bounce, parent
/// clicks resolve to `/parent` so the user lands somewhere meaningful
/// without flashing an inaccessible page. Staff users are unaffected.
///
/// Shared by both `NotificationsPage` and the `NotificationDropdown`
/// row tap handler — single source of truth for the rule.
String resolveNotificationNavUrl(String url, {required bool isParent}) {
  if (!isParent) return url;
  if (url.startsWith('/parent')) return url;
  return '/parent';
}
