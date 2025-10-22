/// product_searchable_dropdown.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mawa_api/mawa_api.dart';

/// A reusable searchable dropdown specialized for Products.
/// - Built-in API search via ProductService().search(query)
/// - Built-in quick-create via ProductService().post(payload)
/// - Returns the selected (or newly created) Product via onChanged
class ProductSearchableDropdown extends StatefulWidget {
  final void Function(Product? value) onChanged;
  final Product? initialValue;

  /// Show the “Create 'query'…” affordance if nothing matches.
  final bool allowQuickCreate;

  /// Field visuals
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
        allowQuickCreate: widget.allowQuickCreate,
        types: widget.types,
      ),
    );
    if (picked != null) {
      setState(() => _selected = picked);
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deco =
        (widget.decoration ??
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

/// Bottom-sheet picker with API search + “Quick Create”.
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
  String _lastQuery = '';
  int _token = 0;
  List<Product> _results = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _queryCtrl.addListener(_onQueryChanged);
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (_queryCtrl.text.isNotEmpty) {
        _runSearch(_queryCtrl.text.trim());
      }
    });
  }

  Future<void> _runSearch(String q) async {
    final myToken = ++_token;
    setState(() {
      _loading = true;
      _lastQuery = q;
    });
    try {
      // --- API call (adjust if your mawa_api differs) ---
      final svc = ProductService();
      // Prefer a dedicated search; fall back to getAll with filter-like behavior if needed.
      dynamic raw;
      try {
        raw = await svc.getAll(widget.types); //
        if (q.isNotEmpty && raw is List) {
          raw = raw.where((p) {
            final needle = q.toLowerCase();
            return p.description.toLowerCase().contains(needle);
          }).toList();
        } // recommended
      } catch (_) {
        raw = await svc.getAll(widget.types); // fallback
        if (q.isNotEmpty && raw is List) {
          raw = raw.where((p) {
            final code = (p['code'] ?? '').toString().toLowerCase();
            final desc = (p['description'] ?? '').toString().toLowerCase();
            final needle = q.toLowerCase();
            return code.contains(needle) || desc.contains(needle);
          }).toList();
        }
      }

      final list = <Product>[];
      if (raw is List) {
        for (final p in raw) {
          try {
            list.add(p);
          } catch (_) {}
        }
      }
      if (!mounted || myToken != _token) return;
      setState(() => _results = list);
    } catch (e) {
      if (!mounted || myToken != _token) return;
      setState(() => _results = const []);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted && myToken == _token) setState(() => _loading = false);
    }
  }

  bool get _canOfferCreate {
    if (!widget.allowQuickCreate) return false;
    final q = _lastQuery.trim();
    if (q.isEmpty) return false;
    return !_results.any(
      (e) =>
          e.description.toLowerCase() == q.toLowerCase() ||
          e.code.toLowerCase() == q.toLowerCase(),
    );
  }

  Future<void> _openQuickCreate(String initialName) async {
    // final created = await showModalBottomSheet<Product>(
    //   context: context,
    //   isScrollControlled: true,
    //   useSafeArea: true,
    //   builder: (_) => const _QuickCreateProductSheet(),
    // );
    // if (created != null && mounted) {
    //   Navigator.pop(context, created); // return the new product
    // }
    createProduct(initialName);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  focusNode: _focus,
                  controller: _queryCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) {
                    if (_canOfferCreate) _openQuickCreate(q);
                  },
                  decoration: InputDecoration(
                    labelText: 'Search product',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _queryCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _queryCtrl.clear();
                              _runSearch('');
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _results.isEmpty
                    ? _EmptyState(
                        query: _lastQuery,
                        onCreate: _canOfferCreate ? _openQuickCreate : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: _results.length + (_canOfferCreate ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, i) {
                          if (_canOfferCreate && i == 0) {
                            return _CreateTile(
                              query: _lastQuery,
                              onTap: () {
                                createProduct(_lastQuery);
                              },
                            );
                          }
                          final opt = _results[i - (_canOfferCreate ? 1 : 0)];
                          return ListTile(
                            title: Text(opt.description),
                            subtitle: Text(opt.code),
                            leading: const Icon(Icons.inventory_2_outlined),
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

  Future<void> createProduct(String query) async {
    final payload = <String, dynamic>{
      "description": query,
      "type": 'CONSUMABLE',
      "category": 'CONSUMABLE',
      "autoGenerateCode": 'X',
      "baseUnitOfMeasure": 'EA',
    };

    setState(() => _saving = true);
    try {
      Product created = await ProductService().post(payload);
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Inline “Quick Create Product” sheet that POSTs your payload:
/// {
///   "code": "string",
///   "description": "string",
///   "type": "string",
///   "category": "string",
///   "baseUnitOfMeasure": "string",
///   "price": 0,
///   "pricingType": "string",
///   "autoGenerateCode": "string"
/// }
class _QuickCreateProductSheet extends StatefulWidget {
  const _QuickCreateProductSheet();

  @override
  State<_QuickCreateProductSheet> createState() =>
      _QuickCreateProductSheetState();
}

class _QuickCreateProductSheetState extends State<_QuickCreateProductSheet> {
  final _formKey = GlobalKey<FormState>();

  final _descCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: 'CONSUMABLE');
  final _categoryCtrl = TextEditingController(text: 'CONSUMABLE');
  final _uomCtrl = TextEditingController(text: 'EA');
  final _priceCtrl = TextEditingController(text: '0');
  final _pricingTypeCtrl = TextEditingController(text: 'STANDARD');

  bool _autoGen = true;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _codeCtrl.dispose();
    _typeCtrl.dispose();
    _categoryCtrl.dispose();
    _uomCtrl.dispose();
    _priceCtrl.dispose();
    _pricingTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;

    final payload = <String, dynamic>{
      "code": _autoGen ? "" : _codeCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "type": _typeCtrl.text.trim(),
      "category": _categoryCtrl.text.trim(),
      "autoGenerateCode": _autoGen ? "1" : "0",
    };

    setState(() => _saving = true);
    try {
      // --- API call (adjust to your mawa_api ProductService) ---
      final resp = await ProductService().post(payload);
      // Map response -> Product
      Product created;
      if (resp is Map) {
        created = Product(
          id: (resp['productId'] ?? resp['id'] ?? resp['code'] ?? '')
              .toString(),
          code: (resp['code'] ?? '').toString(),
          description: (resp['description'] ?? payload['description'])
              .toString(),
        );
      } else {
        created = Product(
          id: (payload['code'] as String).isEmpty
              ? DateTime.now().millisecondsSinceEpoch.toString()
              : payload['code'],
          code: (payload['code'] as String).isEmpty
              ? '(auto)'
              : payload['code'],
          description: payload['description'],
        );
      }
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_box_outlined),
                    const SizedBox(width: 8),
                    const Text(
                      'Quick Create Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Switch(
                      value: _autoGen,
                      onChanged: (v) => setState(() => _autoGen = v),
                    ),
                    const SizedBox(width: 8),
                    const Text('Auto-generate code'),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _codeCtrl,
                  enabled: !_autoGen,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (_) => _autoGen
                      ? null
                      : (_codeCtrl.text.trim().isEmpty
                            ? 'Code required or enable auto-generate'
                            : null),
                ),
                // const SizedBox(height: 10),
                // Row(
                //   children: [
                //     Expanded(
                //       child: TextFormField(
                //         controller: _typeCtrl,
                //         decoration: const InputDecoration(
                //             labelText: 'Type', border: OutlineInputBorder()),
                //       ),
                //     ),
                //     Expanded(
                //       child: SearchableDropdown(
                //           field: 'PRODUCT-TYPE',
                //           label: 'Product Type',
                //           initialCode: '',
                //           onChanged: (p) {}),
                //     ),
                //     const SizedBox(width: 10),
                //     Expanded(
                //       child: SearchableDropdown(
                //           field: 'PRODUCT-CATEGORY',
                //           label: 'Product Category',
                //           initialCode: '',
                //           onChanged: (p) {}),
                //     ),
                //     Expanded(
                //       child: TextFormField(
                //         controller: _categoryCtrl,
                //         decoration: const InputDecoration(
                //             labelText: 'Category',
                //             border: OutlineInputBorder()),
                //       ),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Create'),
                ),
              ],
            ),
          ),
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
