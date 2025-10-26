import 'package:flutter/material.dart';

/// MawaCustomScaffold
/// A production-ready, responsive scaffold that adapts navigation
/// between Drawer (mobile), NavigationRail (tablet/desktop), and
/// optional BottomNavigationBar.
///
/// Highlights
/// - Single source of truth for nav destinations
/// - Works with imperative Navigator or declarative GoRouter (pass callbacks)
/// - Supports a persistent side panel on wide screens
/// - Optional maxContentWidth to center content on large displays
/// - Material 3 ready
///
/// Usage example at the bottom of this file.
class MawaScaffold extends StatefulWidget {
  const MawaScaffold({
    super.key,
    this.title,
    this.body,
    this.fab,
    this.actions,
    this.leading,
    this.onTapLeading,
    this.destinations = const <MawaDestination>[],
    this.selectedIndex = 0,
    this.onDestinationSelected,
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
  });

  /// Optional title rendered in the AppBar (mobile) or top of content area.
  final String? title;

  /// Primary content
  final Widget? body;

  /// Floating action button
  final Widget? fab;

  /// App bar actions
  final List<Widget>? actions;

  /// App bar leading widget (e.g., logo). If null, a default hamburger/menu is used on mobile
  /// when destinations are provided.
  final Widget? leading;
  final VoidCallback? onTapLeading;

  /// Unified navigation model
  final List<MawaDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  /// Controls whether a bottom bar appears on narrow screens when destinations are provided.
  final bool bottomBarOnMobile;

  /// If true, use an extended NavigationRail on very wide screens.
  final bool extendRailOnDesktop;

  /// Optional Drawer header (mobile)
  final Widget? drawerHeader;

  /// Builders to inject custom header/footer inside the rail area.
  final Widget Function(BuildContext context, bool extended)? headerBuilder;
  final Widget Function(BuildContext context)? footerBuilder;

  /// Sizes
  final double railWidth;
  final double railExtendedWidth;

  /// Constrain and center content on very large screens
  final double? maxContentWidth;

  /// Colors and elevation
  final Color? backgroundColor;
  final double? appBarElevation;
  final bool appBarPinned;

  /// Forwarded to Scaffold
  final bool? resizeToAvoidBottomInset;

  /// Override entire AppBar with a custom PreferredSizeWidget
  final PreferredSizeWidget? customAppBar;

  @override
  State<MawaScaffold> createState() => _MawaScaffoldState();
}

class _MawaScaffoldState extends State<MawaScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _hasDestinations => widget.destinations.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 700;
    final bool isTablet = width >= 700 && width < 1200;
    final bool isDesktop = width >= 1200;

    final bool useBottomBar = _hasDestinations && widget.bottomBarOnMobile && isMobile;
    final bool showDrawer = _hasDestinations && isMobile;
    final bool showRail = _hasDestinations && !isMobile;
    final bool extendedRail = widget.extendRailOnDesktop && isDesktop;

    final PreferredSizeWidget appBar = widget.customAppBar ?? _buildDefaultAppBar(
      context: context,
      isMobile: isMobile,
      showDrawer: showDrawer,
    );

    // BODY with optional rail
    Widget content = _buildBodyArea(context, isMobile, showRail, extendedRail);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor ?? theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      appBar: widget.appBarPinned ? appBar : null,
      floatingActionButton: widget.fab,
      drawer: showDrawer ? _buildDrawer(context) : null,
      bottomNavigationBar: useBottomBar ? _buildBottomBar(context, colorScheme) : null,
      body: widget.appBarPinned ? content : CustomScrollView(
        slivers: [
          SliverAppBar(
            title: widget.title != null ? Text(widget.title!) : null,
            centerTitle: isMobile,
            elevation: widget.appBarElevation ?? 0,
            pinned: true,
            leading: _buildAppBarLeading(isMobile, showDrawer),
            actions: widget.actions,
          ),
          SliverToBoxAdapter(child: content),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar({
    required BuildContext context,
    required bool isMobile,
    required bool showDrawer,
  }) {
    return AppBar(
      elevation: widget.appBarElevation ?? 0,
      centerTitle: isMobile,
      title: widget.title != null ? Text(widget.title!) : null,
      leading: _buildAppBarLeading(isMobile, showDrawer),
      actions: widget.actions,
    );
  }

  Widget? _buildAppBarLeading(bool isMobile, bool showDrawer) {
    if (widget.leading != null) {
      return InkWell(
        onTap: widget.onTapLeading,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: widget.leading,
        ),
      );
    }

    if (isMobile && showDrawer) {
      return IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      );
    }
    return null;
  }

  Widget _buildBodyArea(BuildContext context, bool isMobile, bool showRail, bool extendedRail) {
    final Widget core = _constrainedContent(child: widget.body ?? const SizedBox.shrink());

    if (!showRail) {
      return SafeArea(child: core);
    }

    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNavigationRail(context, extendedRail),
          const VerticalDivider(width: 1),
          Expanded(child: core),
        ],
      ),
    );
  }

  Widget _constrainedContent({required Widget child}) {
    if (widget.maxContentWidth == null) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxContentWidth!),
        child: child,
      ),
    );
  }

  // --------------------------- Navigation (Drawer / Rail / Bottom) ---------------------------

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.drawerHeader != null) widget.drawerHeader!,
            if (widget.drawerHeader != null) const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.destinations.length,
                itemBuilder: (context, index) {
                  final d = widget.destinations[index];
                  final selected = index == widget.selectedIndex;
                  return ListTile(
                    leading: Icon(d.icon),
                    title: Text(d.label),
                    selected: selected,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onDestinationSelected?.call(index);
                    },
                  );
                },
              ),
            ),
            if (widget.footerBuilder != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: widget.footerBuilder!(context),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context, bool extended) {
    final bool showLabels = extended;

    return NavigationRail(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      labelType: showLabels ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
      extended: extended,
      minWidth: widget.railWidth,
      groupAlignment: -1.0,
      leading: widget.headerBuilder != null
          ? Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: widget.headerBuilder!(context, extended),
      )
          : null,
      trailing: widget.footerBuilder != null
          ? Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: widget.footerBuilder!(context),
      )
          : null,
      destinations: [
        for (final d in widget.destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: d.selectedIcon != null ? Icon(d.selectedIcon) : null,
            label: Text(d.label),
          ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, ColorScheme colorScheme) {
    return NavigationBar(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      destinations: [
        for (final d in widget.destinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: d.selectedIcon != null ? Icon(d.selectedIcon) : null,
            label: d.label,
          ),
      ],
    );
  }
}

/// A simple destination model to keep nav consistent across Drawer/Rail/BottomBar.
class MawaDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  const MawaDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });
}

// --------------------------- Example Usage ---------------------------
// Copy the widget above into your project (e.g., lib/widgets/mawa_custom_scaffold.dart),
// then use it like this:
/*
class DemoPage extends StatefulWidget {
  const DemoPage({super.key});
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  int index = 0;

  final destinations = const [
    MawaDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
    MawaDestination(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Customers'),
    MawaDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Invoices'),
    MawaDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return MawaCustomScaffold(
      title: 'Mawa Demo',
      destinations: destinations,
      selectedIndex: index,
      onDestinationSelected: (i) {
        setState(() => index = i);
        // If using GoRouter, call context.go(routes[i]); here.
      },
      headerBuilder: (ctx, extended) => Row(
        mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          const FlutterLogo(size: 28),
          if (extended) const SizedBox(width: 8),
          if (extended) const Text('Mawa', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      footerBuilder: (ctx) => const Text('v1.0.0', textAlign: TextAlign.center),
      fab: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      maxContentWidth: 1200,
      body: _DemoBody(index: index),
    );
  }
}

class _DemoBody extends StatelessWidget {
  const _DemoBody({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Padding(
        key: ValueKey(index),
        padding: const EdgeInsets.all(16.0),
        child: switch (index) {
          0 => const Center(child: Text('Dashboard')),
          1 => const Center(child: Text('Customers')),
          2 => const Center(child: Text('Invoices')),
          3 => const Center(child: Text('Settings')),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}
*/
