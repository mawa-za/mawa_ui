import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mawa_api/mawa_api.dart';

import '../services/navigation_service.dart';
import 'mawa-scaffold.dart';

/// Returns icon pairs for common workcenters.
(IconData, IconData?) _iconFor(String id) {
  switch (id) {
    case 'cashup':
      return (Icons.payments, Icons.payments_outlined);
    case 'claim':
      return (Icons.assignment, Icons.assignment_outlined);
    default:
      return (Icons.circle, Icons.circle_outlined);
  }
}

/// Shorten labels to avoid overflow; keep original for tooltips.
String _trimLabel(String input, {int maxChars = 14}) {
  final s = input.trim();
  if (s.length <= maxChars) return s;
  return s.substring(0, maxChars - 1) + '…';
}

/// Strongly-typed decoded destination with both short and full labels.
class _DecodedDest {
  final MawaDestination dest;
  final String fullLabel;
  final int sortPos;
  _DecodedDest(this.dest, this.fullLabel, this.sortPos);
}

/// Converts your API payload → sorted List<_DecodedDest>
List<_DecodedDest> _decodeWorkcenters(dynamic json) {
  if (json is! List) return const <_DecodedDest>[];

  final items = <_DecodedDest>[];

  for (final e in json.whereType<Map<String, dynamic>>()) {
    final wc = (e['workcenter'] ?? {}) as Map<String, dynamic>;
    final id = (wc['id'] ?? '').toString();
    final fullLabel = (wc['description'] ?? id).toString();
    final path = (wc['path'] ?? id).toString();
    final posRaw = e['position'];
    final sortPos = (posRaw is int) ? posRaw : int.tryParse('${posRaw ?? ''}') ?? 9999;

    if (id.isEmpty) continue; // ignore invalid entry

    final (icon, selectedIcon) = _iconFor(id);
    final dest = MawaDestination(
      icon: icon,
      selectedIcon: selectedIcon,
      label: _trimLabel(fullLabel),
      route: path,
      tooltip: fullLabel, // if your MawaDestination supports it
    );

    items.add(_DecodedDest(dest, fullLabel, sortPos));
  }

  items.sort((a, b) => a.sortPos.compareTo(b.sortPos));
  return List.unmodifiable(items);
}

/// Strategy for handling many destinations on mobile.
enum _OverflowStrategy {
  /// Use a Drawer/NavigationRail instead of a BottomNavigationBar if > maxBottomItems.
  switchToRailOrDrawer,

  /// Keep a BottomNavigationBar but show first (maxBottomItems-1) items + a "More" slot.
  bottomBarWithMoreItem,
}

/// Scaffold that auto-fetches destinations from API and navigates via NavigationService.
class MawaScaffoldRemote extends StatefulWidget {
  const MawaScaffoldRemote({
    super.key,
    this.title,
    this.body,
    this.fab,
    this.actions,
    this.leading,
    this.onTapLeading,
    this.bottomBarOnMobile = true,
    this.extendRailOnDesktop = true,
    this.drawerHeader,
    this.headerBuilder,
    this.footerBuilder,
    this.railWidth = 72.0,
    this.railExtendedWidth = 280.0,
    this.maxContentWidth,
    this.backgroundColor,
    this.appBarElevation,
    this.appBarPinned = true,
    this.resizeToAvoidBottomInset,
    this.customAppBar,
    this.roleKey = 'role',

    /// Enhancements
    this.maxBottomItems = 5,
    this.mobileOverflowStrategy = _OverflowStrategy.switchToRailOrDrawer,
  });

  final String? title;
  final Widget? body;
  final Widget? fab;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onTapLeading;
  final bool bottomBarOnMobile;
  final bool extendRailOnDesktop;
  final Widget? drawerHeader;
  final Widget Function(BuildContext, bool extended)? headerBuilder;
  final Widget Function(BuildContext)? footerBuilder;
  final double railWidth;
  final double railExtendedWidth;
  final double? maxContentWidth;
  final Color? backgroundColor;
  final double? appBarElevation;
  final bool appBarPinned;
  final bool? resizeToAvoidBottomInset;
  final PreferredSizeWidget? customAppBar;
  final String roleKey;

  /// Max items shown in a bottom bar before overflow handling kicks in.
  final int maxBottomItems;

  /// How to handle more than [maxBottomItems] destinations on mobile.
  final _OverflowStrategy mobileOverflowStrategy;

  @override
  State<MawaScaffoldRemote> createState() => _MawaScaffoldRemoteState();
}

class _MawaScaffoldRemoteState extends State<MawaScaffoldRemote> {
  bool _loading = true;
  Object? _error;
  List<_DecodedDest> _decoded = const [];

  List<MawaDestination> get _destinations =>
      _decoded.map((e) => e.dest).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(widget.roleKey);
      if (role == null || role.isEmpty) {
        throw Exception('Role not found in SharedPreferences under key "${widget.roleKey}".');
      }

      final json = await UserService().getWorkcenters(role);
      _decoded = _decodeWorkcenters(json);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _navigate(String route) {
    if (route.isEmpty) return;
    NavigationService.navigateTo(route);
  }

  /// Whether we should render a bottom bar on mobile (and it won’t overflow).
  bool _useBottomBarOnMobile(BuildContext context) {
    if (!widget.bottomBarOnMobile) return false;
    final count = _destinations.length;
    if (count <= widget.maxBottomItems) return true;

    // If we’re using "More", we’ll still use a bottom bar.
    return widget.mobileOverflowStrategy == _OverflowStrategy.bottomBarWithMoreItem;
  }

  /// Produce a destination list for bottom bar when using the "More" bucket.
  /// Shows (maxBottomItems - 1) real items + a synthetic "More" item.
  List<MawaDestination> _destinationsWithMore() {
    final maxReal = (widget.maxBottomItems - 1).clamp(1, widget.maxBottomItems);
    final primary = _destinations.take(maxReal).toList();
    final more = MawaDestination(
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
      label: 'More',
      route: '', // handled specially
      tooltip: 'More',
    );
    return [...primary, more];
  }

  void _handleSelectWithMore(int index) {
    final maxReal = (widget.maxBottomItems - 1).clamp(1, widget.maxBottomItems);
    // If "More" pressed
    if (index == maxReal) {
      _showMoreSheet();
      return;
    }
    // Navigate to real slot
    final route = _destinations[index].route;
    _navigate(route);
  }

  void _showMoreSheet() {
    final overflow = _destinations.skip(widget.maxBottomItems - 1).toList();
    if (overflow.isEmpty) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: overflow.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = overflow[i];
              return ListTile(
                leading: Icon(d.icon),
                title: Text(d.tooltip ?? d.label),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigate(d.route);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _onDestinationSelected(int index) {
    final useMore =
        widget.mobileOverflowStrategy == _OverflowStrategy.bottomBarWithMoreItem &&
            _destinations.length > widget.maxBottomItems;

    if (useMore) {
      _handleSelectWithMore(index);
      return;
    }

    final route = _destinations[index].route;
    _navigate(route);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: widget.customAppBar ?? AppBar(title: Text(widget.title ?? '')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: widget.customAppBar ?? AppBar(title: Text(widget.title ?? '')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Failed to load destinations',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('$_error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_decoded.isEmpty) {
      return Scaffold(
        appBar: widget.customAppBar ?? AppBar(title: Text(widget.title ?? '')),
        body: const Center(child: Text('No destinations found')),
      );
    }

    final useBottomBar = _useBottomBarOnMobile(context);
    final useMore = useBottomBar &&
        widget.mobileOverflowStrategy == _OverflowStrategy.bottomBarWithMoreItem &&
        _destinations.length > widget.maxBottomItems;

    final effectiveDestinations = useMore ? _destinationsWithMore() : _destinations;

    return MawaScaffold(
      title: widget.title,
      body: widget.body,
      fab: widget.fab,
      actions: widget.actions,
      leading: widget.leading,
      onTapLeading: widget.onTapLeading,

      // Key: avoid overflow and provide "More" when needed
      destinations: effectiveDestinations,
      onDestinationSelected: _onDestinationSelected,
      bottomBarOnMobile: useBottomBar,

      extendRailOnDesktop: widget.extendRailOnDesktop,
      drawerHeader: widget.drawerHeader,
      headerBuilder: widget.headerBuilder,
      footerBuilder: widget.footerBuilder,
      railWidth: widget.railWidth,
      railExtendedWidth: widget.railExtendedWidth,
      maxContentWidth: widget.maxContentWidth,
      backgroundColor: widget.backgroundColor,
      appBarElevation: widget.appBarElevation,
      appBarPinned: widget.appBarPinned,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      customAppBar: widget.customAppBar,
    );
  }
}
