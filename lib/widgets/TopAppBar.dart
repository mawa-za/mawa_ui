// lib/widgets/mawa_top_app_bar.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

/// Mawa Top App Bar (responsive, logo-aware, mobile-centerable)
///
/// Example:
/// Scaffold(
///   appBar: TopAppBar(
///     title: 'Dashboard',
///     logoAssetPath: 'assets/mawa/logo_mark.png',
///     hideLogoBelowWidth: 600,             // auto-hide logo on narrow screens
///     centerTitleOnMobile: true,           // center title on mobile widths
///     centerTitleBreakpoint: 600,          // <=600px => centered
///     onTapLogo: () => context.go('/'),
///     onTapProfile: () => context.go('/profile'),
///     onTapSettings: () => context.go('/settings'),
///     onTapSwitchRole: () => context.go('/select-role'),
///     onLogout: () async { /* ... */ },
///   ),
///   body: ...
/// )
class TopAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;

  /// Optional user info for the right-side account menu.
  final String? userDisplayName;
  final String? userEmail;

  /// Optional trailing actions to inject before the user menu.
  final List<Widget>? actions;

  /// Show a back button.
  final bool showBack;

  /// Callbacks.
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapSettings;
  final VoidCallback? onTapSwitchRole;
  final Future<void> Function()? onLogout;

  /// Styling.
  final Color? backgroundColor;
  final double elevation;
  final double? toolbarHeight;

  /// Logo (leading) options.
  final Widget? leadingLogo;         // If provided, used as-is.
  final String? logoAssetPath;       // Used if leadingLogo is null.
  final double logoHeight;           // Logical px height.
  final double hideLogoBelowWidth;   // Auto-hide logo when screen < this width.
  final VoidCallback? onTapLogo;

  /// Title centering behavior for mobile widths.
  final bool centerTitleOnMobile;
  final double centerTitleBreakpoint; // <= this width => center

  const TopAppBar({
    super.key,
    required this.title,
    this.userDisplayName,
    this.userEmail,
    this.actions,
    this.showBack = false,
    this.onTapProfile,
    this.onTapSettings,
    this.onTapSwitchRole,
    this.onLogout,
    this.backgroundColor,
    this.elevation = 0.5,
    this.toolbarHeight,
    this.leadingLogo,
    this.logoAssetPath,
    this.logoHeight = 24,
    this.hideLogoBelowWidth = 600,
    this.onTapLogo,
    this.centerTitleOnMobile = true,
    this.centerTitleBreakpoint = 600,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<TopAppBar> createState() => _TopAppBarState();
}

class _TopAppBarState extends State<TopAppBar> {
  late String _displayName;
  String? _email;

  @override
  void initState() {
    super.initState();
    _displayName = (widget.userDisplayName?.trim().isNotEmpty ?? false)
        ? widget.userDisplayName!.trim()
        : 'User';
    _email = widget.userEmail;
    _hydrateUserSafe();
  }

  Future<void> _hydrateUserSafe() async {
    // Optionally hydrate from your "me" endpoint.
    // try {
    //   final me = await User.details();
    //   if (!mounted) return;
    //   setState(() {
    //     _displayName = me.displayName ?? me.username ?? _displayName;
    //     _email = me.email ?? _email;
    //   });
    // } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Title: fluid scaling with bounds
    final titleFontSize = (width * 0.018).clamp(16.0, 22.0);

    // Toolbar height: slightly taller on bigger screens
    final computedToolbarHeight = widget.toolbarHeight ??
        (width < 400
            ? 56.0
            : width < 800
            ? 58.0
            : width < 1200
            ? 60.0
            : 64.0);

    // Center title on narrow screens if enabled
    final centerTitle =
        widget.centerTitleOnMobile && width <= widget.centerTitleBreakpoint;

    final isMobileNative = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final cs = Theme.of(context).colorScheme;

    // Leading: back button has priority; else logo (if wide enough)
    Widget? leading;
    if (widget.showBack) {
      leading = IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      );
    } else if (width >= widget.hideLogoBelowWidth) {
      final logo = widget.leadingLogo ??
          (widget.logoAssetPath != null
              ? Image.asset(
            widget.logoAssetPath!,
            height: widget.logoHeight,
            fit: BoxFit.contain,
          )
              : null);
      if (logo != null) {
        leading = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTapLogo,
            child: Align(
              alignment: Alignment.centerLeft,
              child: logo,
            ),
          ),
        );
      }
    }

    return AppBar(
      backgroundColor: widget.backgroundColor ?? cs.surface,
      elevation: widget.elevation,
      centerTitle: centerTitle,
      toolbarHeight: computedToolbarHeight,
      leading: leading,
      titleSpacing: widget.showBack ? 0 : null,
      title: Text(
        widget.title,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: titleFontSize,
        ),
      ),
      actions: [
        if (widget.actions != null) ...widget.actions!,
        if (isMobileNative) const _ScanTenantAction(),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
        ),
        const SizedBox(width: 4),
        _UserMenu(
          displayName: _displayName,
          email: _email,
          compact: width < 600,
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

enum _MenuAction { profile, settings, switchRole, logout }

/// Right-side account menu (avatar, name, email) — fully responsive.
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
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Responsive scaling
    final nameFontSize = width < 400
        ? 13.0
        : width < 800
        ? 14.0
        : width < 1200
        ? 15.0
        : 16.0;

    final emailFontSize = width < 400
        ? 11.0
        : width < 800
        ? 12.0
        : width < 1200
        ? 13.0
        : 14.0;

    final avatarRadius = width < 400
        ? 14.0
        : width < 800
        ? 16.0
        : width < 1200
        ? 18.0
        : 20.0;

    final avatar = CircleAvatar(
      radius: avatarRadius,
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: avatarRadius * 0.7,
        ),
      ),
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
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: nameFontSize,
                    ),
                  ),
                  if (email != null && email!.isNotEmpty)
                    Text(
                      email!,
                      style: TextStyle(
                        fontSize: emailFontSize,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
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

/// Optional: a small action to scan/enter tenant URL on mobile (kept as utility)
class _ScanTenantAction extends StatelessWidget {
  const _ScanTenantAction();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Scan / Enter Tenant URL',
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () async {
        // Open your tenant picker / scanner here if needed.
      },
    );
  }
}
