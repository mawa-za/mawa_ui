// product_searchable_dropdown.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mawa_api/mawa_api.dart';

/// Product picker with:
/// - First-time remote fetch (seed) when the user types >= minSeedChars
/// - All subsequent searches are local in-memory filtering on that seed
/// - Optional quick-create
class ProductSearchableDropdown extends StatefulWidget {
  final void Function(Product? value) onChanged;
  final Product? initialValue;

  /// Show "Create 'query'..." when nothing matches (after seed is loaded).
  final bool allowQuickCreate;

  /// Field visuals
  final String label;
  final String? hintText;
  final bool readOnly;
  final bool allowClear;
  final InputDecoration? decoration;

  /// Optional server filter
  final List<String> types;

  /// Minimum chars required for the initial seed fetch
  final int minSeedChars;

  /// Show product code on the tile
  final bool showCodeInList;

  const ProductSearchableDropdown({
    super.key,
    required this.onChanged,
    this.initialValue,
    this.allowQuickCreate = true,
    this.label = 'Select Product',
    this.hintText,
    this.readOnly = false,
    this.allowClear = true,
    this.decoration,
    required this.types,
    this.minSeedChars = 3,
    this.showCodeInList = true,
  });

  @override
  State<ProductSearchableDropdown> createState() =>
      _ProductSearchableDropdownState();
}

class _ProductSearchableDropdownState extends State<ProductSearchableDropdown> {
  Product? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant ProductSearchableDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _selected = widget.initialValue;
    }
  }

  Future<void> _openPicker() async {
    if (widget.readOnly) return;
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductPickerSheet(
        allowQuickCreate: widget.allowQuickCreate,
        types: widget.types,
        minSeedChars: widget.minSeedChars,
        showCodeInList: widget.showCodeInList,
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _selected = picked);
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deco = (widget.decoration ??
        InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText ?? 'Tap to search products',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.shopping_bag_outlined),
        ))
        .copyWith(
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selected != null && widget.allowClear)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _selected = null);
                widget.onChanged(null);
              },
            ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: widget.readOnly ? null : _openPicker,
          ),
        ],
      ),
    );

    final text = _selected == null
        ? ''
        : '${_selected!.code} — ${_selected!.description}';

    return GestureDetector(
      onTap: _openPicker,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          controller: TextEditingController(text: text),
          decoration: deco,
        ),
      ),
    );
  }
}

/* ========================= Picker Sheet ========================= */

class _ProductPickerSheet extends StatefulWidget {
  final bool allowQuickCreate;
  final List<String> types;
  final int minSeedChars;
  final bool showCodeInList;

  const _ProductPickerSheet({
    required this.allowQuickCreate,
    required this.types,
    required this.minSeedChars,
    required this.showCodeInList,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _listCtrl = ScrollController();
  Timer? _debounce;

  bool _loading = false;
  bool _saving = false;
  String _lastQuery = '';
  List<Product> _visible = const [];

  // Seed state & cache
  String? _seedQuery;
  static final Map<String, List<Product>> _cacheBySeed = {};
  String get _typesKey => widget.types.join('|');
  String get _cacheKey => '$_typesKey|${_seedQuery ?? "(none)"}';
  bool get _hasSeed => _cacheBySeed.containsKey(_cacheKey);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _queryCtrl.addListener(_onQueryChanged);
    _visible = const [];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _focus.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  /* ------------------ Search lifecycle ------------------ */

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final q = _queryCtrl.text.trim();
      _lastQuery = q;

      if (!_hasSeed) {
        // Need the very first server fetch — require minSeedChars
        if (q.length < widget.minSeedChars) {
          setState(() => _visible = const []);
          return;
        }
        await _fetchSeed(q);
        _applyLocalFilter(q);
        return;
      }

      // We have a seed; filter locally
      _applyLocalFilter(q);
    });
  }

  Future<void> _fetchSeed(String seed) async {
    setState(() => _loading = true);
    try {
      final svc = ProductService();
      final list = await svc.getAll(widget.types, seed);
      _seedQuery = seed;
      _cacheBySeed[_cacheKey] = List<Product>.from(list ?? const <Product>[]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load products failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLocalFilter(String q) {
    final all = _cacheBySeed[_cacheKey] ?? const <Product>[];
    if (q.isEmpty) {
      setState(() => _visible = all);
      return;
    }
    final needle = q.toLowerCase();
    setState(() {
      _visible = all.where((p) {
        final code = p.code.toLowerCase();
        final desc = p.description.toLowerCase();
        return code.contains(needle) || desc.contains(needle);
      }).toList();
    });
  }

  bool get _canOfferCreate {
    if (!_hasSeed) return false; // only once we have a seed list
    if (!widget.allowQuickCreate) return false;
    final q = _lastQuery.trim();
    if (q.isEmpty) return false;
    return !_visible.any((e) =>
    e.description.toLowerCase() == q.toLowerCase() ||
        e.code.toLowerCase() == q.toLowerCase());
  }

  Future<void> _changeSeed() async {
    final q = _queryCtrl.text.trim();
    if (q.length < widget.minSeedChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Type at least ${widget.minSeedChars} characters')),
      );
      return;
    }
    // Reset & fetch new seed
    setState(() {
      _seedQuery = null;
      _visible = const [];
    });
    await _fetchSeed(q);
    _applyLocalFilter(q);
    if (_listCtrl.hasClients) _listCtrl.jumpTo(0);
  }

  /* ------------------ Quick Create ------------------ */

  Future<void> _createFromQuery(String q) async => _createProduct(q);

  Future<void> _createProduct(String query) async {
    setState(() => _saving = true);
    try {
      final created = await ProductService().post({
        "description": query,
        "type": 'CONSUMABLE',
        "category": 'CONSUMABLE',
        "autoGenerateCode": 'X',
        "baseUnitOfMeasure": 'EA',
      });

      if (created is Product && _hasSeed) {
        final list = List<Product>.from(_cacheBySeed[_cacheKey] ?? const []);
        list.insert(0, created);
        _cacheBySeed[_cacheKey] = list;
        _applyLocalFilter(_lastQuery);
      }

      if (!mounted) return;
      Navigator.pop(context, created is Product ? created : null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /* ------------------ UI ------------------ */

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final needSeed = !_hasSeed && _lastQuery.length < widget.minSeedChars;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),

              // Search + actions row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryCtrl,
                        focusNode: _focus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (q) {
                          if (_canOfferCreate) _createFromQuery(q);
                          if (!_hasSeed && q.length >= widget.minSeedChars) {
                            _changeSeed(); // fetch seed directly on submit
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Search product',
                          hintText: _hasSeed
                              ? 'Filter in results (local) — seed: “${_seedQuery ?? ''}”'
                              : 'Type at least ${widget.minSeedChars} characters',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_queryCtrl.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _queryCtrl.clear(),
                                ),
                              IconButton(
                                tooltip: _hasSeed ? 'Change seed' : 'Fetch seed',
                                icon: const Icon(Icons.sync),
                                onPressed: _loading ? null : _changeSeed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_loading) const LinearProgressIndicator(minHeight: 2),

              Expanded(
                child: needSeed
                    ? _NeedMoreCharsNotice(
                  typed: _lastQuery.length,
                  requiredChars: widget.minSeedChars,
                )
                    : _visible.isEmpty
                    ? _EmptyState(
                  query: _lastQuery,
                  onCreate: _canOfferCreate ? _createFromQuery : null,
                )
                    : ListView.separated(
                  controller: _listCtrl,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _visible.length + (_canOfferCreate ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    if (_canOfferCreate && i == 0) {
                      return _CreateTile(
                        query: _lastQuery,
                        onTap: () => _createFromQuery(_lastQuery),
                      );
                    }
                    final p = _visible[i - (_canOfferCreate ? 1 : 0)];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(p.description),
                      subtitle: widget.showCodeInList ? Text(p.code) : null,
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------ Small helpers / states ------------------ */

class _NeedMoreCharsNotice extends StatelessWidget {
  final int typed;
  final int requiredChars;
  const _NeedMoreCharsNotice({
    required this.typed,
    required this.requiredChars,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (requiredChars - typed).clamp(0, requiredChars);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard, size: 40, color: Colors.black26),
            const SizedBox(height: 8),
            Text(
              remaining == 0
                  ? 'Press enter to fetch'
                  : 'Type $remaining more character${remaining == 1 ? '' : 's'} to search…',
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  const _CreateTile({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.add_circle_outline),
      title: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            const TextSpan(text: 'Create '),
            TextSpan(
              text: '“$query”',
              style: const TextStyle(decoration: TextDecoration.underline),
            ),
            const TextSpan(text: ' as a new product'),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  final void Function(String query)? onCreate;
  const _EmptyState({required this.query, this.onCreate});

  @override
  Widget build(BuildContext context) {
    final canCreate = onCreate != null && query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 42, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'No results. Change seed or try another term.'
                  : 'No products found for “$query”.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (canCreate) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => onCreate!(query),
                icon: const Icon(Icons.add),
                label: Text('Create “$query”'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
