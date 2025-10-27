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

/// Converts your API payload → List<MawaDestination>
List<MawaDestination> _decodeWorkcenters(dynamic json) {
  if (json is! List) return const <MawaDestination>[];

  final items = json
      .whereType<Map<String, dynamic>>()
      .map((e) {
    final wc = (e['workcenter'] ?? {}) as Map<String, dynamic>;
    final id = (wc['id'] ?? '').toString();
    final label = (wc['description'] ?? id).toString();
    final path = (wc['path'] ?? id).toString();
    final pos = e['position'];
    final position = (pos is int) ? pos : int.tryParse(pos?.toString() ?? '');
    final (icon, selectedIcon) = _iconFor(id);

    return (
    position: position ?? 9999,
    dest: MawaDestination(
      icon: icon,
      selectedIcon: selectedIcon,
      label: label,
      route: path,
    )
    );
  })
      .toList();

  items.sort((a, b) => a.position.compareTo(b.position));
  return items.map((x) => x.dest).toList(growable: false);
}

/// Scaffold that auto-fetches destinations from API and navigates via NavigationService
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

  @override
  State<MawaScaffoldRemote> createState() => _MawaScaffoldRemoteState();
}

class _MawaScaffoldRemoteState extends State<MawaScaffoldRemote> {
  bool _loading = true;
  Object? _error;
  List<MawaDestination> _destinations = const [];

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
        throw Exception('Role not found in SharedPreferences under key "${widget.roleKey}"');
      }

      final json = await UserService().getWorkcenters(role);
      _destinations = _decodeWorkcenters(json);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _onDestinationSelected(int index) {
    final route = _destinations[index].route;
    NavigationService.navigateTo(route); // <── integrated navigation
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? '')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? '')),
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
                Text(_error.toString(), textAlign: TextAlign.center),
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

    if (_destinations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? '')),
        body: const Center(child: Text('No destinations found')),
      );
    }

    return MawaScaffold(
      title: widget.title,
      body: widget.body,
      fab: widget.fab,
      actions: widget.actions,
      leading: widget.leading,
      onTapLeading: widget.onTapLeading,
      destinations: _destinations,
      onDestinationSelected: _onDestinationSelected,
      bottomBarOnMobile: widget.bottomBarOnMobile,
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
