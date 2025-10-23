import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mawa_api/mawa_api.dart';

/// A reusable searchable dropdown specialized for Products.
/// - First query (>=3 chars) triggers a one-time API fetch (per `types`), cached.
/// - Subsequent queries are local, debounced filtering on the cached list.
/// - Optional quick-create if nothing matches.
/// - Emits the selected (or newly created) Product via onChanged.
class ProductSearchableDropdown extends StatefulWidget {
  final void Function(Product? value) onChanged;
  final Product? initialValue;

  final bool allowQuickCreate;
  final String label;
  final String? hintText;
  final bool readOnly;
  final bool allowClear;
  final InputDecoration? decoration;
  final List<String> types;

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
        types: widget.types,
        allowQuickCreate: widget.allowQuickCreate,
      ),
    );
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
  const _ProductPickerSheet({
    required this.allowQuickCreate,
    required this.types,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  bool _loading = false;
  bool _saving = false;
  String _lastQuery = '';
  List<Product> _results = const [];

  // Cache per types signature
  static final Map<String, List<Product>> _cacheByTypes = {};
  String get _cacheKey => widget.types.join('|');

  bool get _hasCache => _cacheByTypes.containsKey(_cacheKey);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _queryCtrl.addListener(_onQueryChanged);
    // No initial fetch: user must type >= 3 chars first.
    setState(() {
      _results = const [];
      _lastQuery = '';
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // First time: need >= 3 chars to fetch; thereafter filter locally.
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final q = _queryCtrl.text.trim();
      _lastQuery = q;

      if (!_hasCache) {
        // Initial search: require 3 chars to hit API
        if (q.length < 3) {
          setState(() => _results = const []);
          return;
        }
        await _fetchAllOnce(); // one-shot load
        _applyLocalFilter(q);
        return;
      }

      // After cache exists → purely local filter (any length)
      _applyLocalFilter(q);
    });
  }

  Future<void> _fetchAllOnce() async {
    if (_hasCache) return; // already loaded
    setState(() => _loading = true);
    try {
      final svc = ProductService();
      dynamic raw = await svc.getAll(widget.types);

      List<Product> all = const [];
      if (raw is List<Product>) {
        all = raw;
      } else if (raw is List) {
        final list = <Product>[];
        for (final p in raw) {
          try {
            if (p is Product) {
              list.add(p);
            } else if (p is Map) {
              list.add(Product(
                id: (p['productId'] ?? p['id'] ?? p['code'] ?? '').toString(),
                code: (p['code'] ?? '').toString(),
                description: (p['description'] ?? '').toString(),
              ));
            }
          } catch (_) {}
        }
        all = list;
      }
      _cacheByTypes[_cacheKey] = all;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load products failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLocalFilter(String q) {
    final all = _cacheByTypes[_cacheKey] ?? const <Product>[];
    if (q.isEmpty) {
      setState(() => _results = all);
      return;
    }
    final needle = q.toLowerCase();
    setState(() {
      _results = all.where((p) {
        final code = p.code.toLowerCase();
        final desc = p.description.toLowerCase();
        return code.contains(needle) || desc.contains(needle);
      }).toList();
    });
  }

  bool get _canOfferCreate {
    if (!_hasCache) return false; // only after first fetch
    if (!widget.allowQuickCreate) return false;
    final q = _lastQuery.trim();
    if (q.isEmpty) return false;
    return !_results.any((e) =>
    e.description.toLowerCase() == q.toLowerCase() ||
        e.code.toLowerCase() == q.toLowerCase());
  }

  Future<void> _createFromQuery(String q) async => _createProduct(q);

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final need3Chars = !_hasCache && _lastQuery.length < 3;

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
              const SizedBox(height: 8),

              // Search row with refresh
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _focus,
                        controller: _queryCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (q) {
                          if (_canOfferCreate) _createFromQuery(q);
                        },
                        decoration: InputDecoration(
                          labelText: 'Search product',
                          hintText: !_hasCache
                              ? 'Type at least 3 characters to search'
                              : 'Search products',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_queryCtrl.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _queryCtrl.clear(); // listener re-filters
                                  },
                                ),
                              IconButton(
                                tooltip: 'Refresh from server (resets cache)',
                                icon: const Icon(Icons.refresh),
                                onPressed: _loading
                                    ? null
                                    : () async {
                                  // Clear cache and require 3 chars again
                                  _cacheByTypes.remove(_cacheKey);
                                  setState(() {
                                    _results = const [];
                                    _lastQuery = _queryCtrl.text.trim();
                                  });
                                  if (_lastQuery.length >= 3) {
                                    await _fetchAllOnce();
                                    _applyLocalFilter(_lastQuery);
                                  }
                                },
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
                child: need3Chars
                    ? _Type3CharsNotice(count: _lastQuery.length)
                    : _results.isEmpty
                    ? _EmptyState(
                  query: _lastQuery,
                  onCreate: _canOfferCreate ? _createFromQuery : null,
                )
                    : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _results.length + (_canOfferCreate ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    if (_canOfferCreate && i == 0) {
                      return _CreateTile(
                        query: _lastQuery,
                        onTap: () => _createFromQuery(_lastQuery),
                      );
                    }
                    final opt =
                    _results[i - (_canOfferCreate ? 1 : 0)];
                    return ListTile(
                      leading:
                      const Icon(Icons.inventory_2_outlined),
                      title: Text(opt.description),
                      subtitle: Text(opt.code),
                      onTap: () => Navigator.pop(context, opt),
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

  Future<void> _createProduct(String query) async {
    final payload = <String, dynamic>{
      "description": query,
      "type": 'CONSUMABLE',
      "category": 'CONSUMABLE',
      "autoGenerateCode": 'X',
      "baseUnitOfMeasure": 'EA',
    };

    setState(() => _saving = true);
    try {
      final created = await ProductService().post(payload);

      // If a Product returned, add to cache for this types-set (top)
      if (created is Product) {
        final all = List<Product>.from(_cacheByTypes[_cacheKey] ?? const []);
        all.insert(0, created);
        _cacheByTypes[_cacheKey] = all;
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
}

/* ====================== Small UI helpers ====================== */

class _Type3CharsNotice extends StatelessWidget {
  final int count;
  const _Type3CharsNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    final remain = (3 - count).clamp(0, 3);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          remain == 0
              ? 'Searching…'
              : 'Type at least 3 characters to search\n($remain more to go)',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade700),
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
                  ? 'Type to search products'
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
