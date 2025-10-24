// lib/widgets/mawa_top_app_bar.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mawa_api/mawa_api.dart';

/// A reusable top app bar for Mawa Business Suite:
/// - Shows title
/// - Tenant badge (auto from MawaAPI if not provided)
/// - User avatar + name (fallback friendly)
/// - Popup menu: Profile, Settings, Switch Role, Logout
///
/// Usage:
/// Scaffold(
///   appBar: MawaTopAppBar(
///     title: 'Dashboard',
///     onTapProfile: () => context.go('/profile'),
///     onTapSettings: () => context.go('/settings'),
///     onTapSwitchRole: () => context.go('/select-role'),
///     onLogout: () async {
///       await User.logout();
///       if (context.mounted) context.go('/login');
///     },
///   ),
///   body: ...
/// )
class TopAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;

  /// Optional pre-fetched user display & email. If null, the widget shows a safe fallback.
  final String? userDisplayName;
  final String? userEmail;

  /// Optional tenant host/name. If null, it tries MawaAPI.getTenant() and falls back to '-'.
  final String? tenantLabel;

  /// Optional trailing actions to inject before the user menu
  final List<Widget>? actions;

  /// Show a back button instead of the menu icon (e.g., in detail screens)
  final bool showBack;

  /// Navigation callbacks
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapSettings;
  final VoidCallback? onTapSwitchRole;
  final Future<void> Function()? onLogout;

  /// Optional background color / elevation override
  final Color? backgroundColor;
  final double elevation;

  const TopAppBar({
    super.key,
    required this.title,
    this.userDisplayName,
    this.userEmail,
    this.tenantLabel,
    this.actions,
    this.showBack = false,
    this.onTapProfile,
    this.onTapSettings,
    this.onTapSwitchRole,
    this.onLogout,
    this.backgroundColor,
    this.elevation = 0.5,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<TopAppBar> createState() => _TopAppBarState();
}

class _TopAppBarState extends State<TopAppBar> {
  String? _tenant;
  String? _displayName;
  String? _email;

  @override
  void initState() {
    super.initState();
    _tenant = (widget.tenantLabel ?? _tryGetTenant()) as String?;
    _displayName = widget.userDisplayName ?? 'User';
    _email = widget.userEmail;
    _hydrateUserSafe();
  }

  Future<String> _tryGetTenant() async {
    try {
      // If your SDK exposes a getter; otherwise pass tenantLabel from main
      final t = await MawaAPI.getTenant();
      if (t is String && t.isNotEmpty) return t;
    } catch (_) {}
    return '-';
  }

  Future<void> _hydrateUserSafe() async {
    // If you have an endpoint for "me", hydrate here. Wrap in try/catch to avoid crashes.
    // Example (adjust to your SDK):
    // try {
    //   final me = await User.details(); // or User.me()
    //   if (!mounted) return;
    //   setState(() {
    //     _displayName = me.displayName ?? me.username ?? widget.userDisplayName ?? 'User';
    //     _email = me.email ?? widget.userEmail;
    //   });
    // } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS);
    final showTenant = _tenant != null && _tenant!.trim().isNotEmpty && _tenant != '-';
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
      elevation: widget.elevation,
      centerTitle: false,
      leading: widget.showBack
          ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      )
          : null,
      titleSpacing: widget.showBack ? 0 : null,
      title: Row(
        children: [
          Flexible(
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (showTenant) _TenantBadge(label: _tenant!),
        ],
      ),
      actions: [
        if (widget.actions != null) ...widget.actions!,
        // Optional “scan tenant QR” action for non-web
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) _ScanTenantAction(),
        // Notifications placeholder
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
        ),
        const SizedBox(width: 4),
        _UserMenu(
          displayName: _displayName ?? 'User',
          email: _email,
          compact: isMobile,
          onTapProfile: widget.onTapProfile,
          onTapSettings: widget.onTapSettings,
          onTapSwitchRole: widget.onTapSwitchRole,
          onLogout: widget.onLogout,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// --- Tenant chip
class _TenantBadge extends StatelessWidget {
  final String label;
  const _TenantBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tenant',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.business_outlined, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// --- User avatar + name + popup menu
class _UserMenu extends StatelessWidget {
  final String displayName;
  final String? email;
  final bool compact;
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapSettings;
  final VoidCallback? onTapSwitchRole;
  final Future<void> Function()? onLogout;

  const _UserMenu({
    required this.displayName,
    this.email,
    required this.compact,
    this.onTapProfile,
    this.onTapSettings,
    this.onTapSwitchRole,
    this.onLogout,
  });

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 16,
      child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold)),
    );

    return PopupMenuButton<_MenuAction>(
      tooltip: 'Account',
      offset: const Offset(0, kToolbarHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (act) async {
        switch (act) {
          case _MenuAction.profile:
            onTapProfile?.call();
            break;
          case _MenuAction.settings:
            onTapSettings?.call();
            break;
          case _MenuAction.switchRole:
            onTapSwitchRole?.call();
            break;
          case _MenuAction.logout:
            if (onLogout != null) {
              await onLogout!();
            } else {
              // Fallback logout if not provided
              try {
                // await User.logout();
              } catch (_) {}
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out')),
                );
              }
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.profile,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.settings,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
          ),
        ),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.switchRole,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.switch_account),
            title: const Text('Switch Role'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logout,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            avatar,
            if (!compact) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (email != null && email!.isNotEmpty)
                    Text(
                      email!,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

enum _MenuAction { profile, settings, switchRole, logout }

// --- Optional: a small action to scan/enter tenant URL on mobile
class _ScanTenantAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Scan / Enter Tenant URL',
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () async {
        // You can open your tenant picker page/dialog here.
        // Example:
        // final ok = await showDialog(...);
      },
    );
  }
}
