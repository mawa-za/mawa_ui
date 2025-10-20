import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:mawa_api/mawa_api.dart';

/// Model for dropdown items
class DropdownItem {
  final String field;
  final String code;
  final String description;

  DropdownItem({
    required this.field,
    required this.code,
    required this.description,
  });

  factory DropdownItem.fromJson(Map<String, dynamic> json) {
    return DropdownItem(
      field: json['field'],
      code: json['code'],
      description: json['description'],
    );
  }

  @override
  String toString() => description; // only show description in UI
}

/// Service to fetch and cache dropdown items per field
class DropdownService {
  static final Map<String, Future<List<DropdownItem>>> _cache = {};

  static Future<List<DropdownItem>> getDropdownItems(String field) {
    if (_cache.containsKey(field)) {
      return _cache[field]!;
    }
    final future = _fetchFromApi(field);
    _cache[field] = future;
    return future;
  }

  static Future<List<DropdownItem>> _fetchFromApi(String field) async {
    try {
      final response = await FieldOptionService().getOptions(field);
      final List<dynamic> data = response;
      return data.map((json) => DropdownItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load dropdown data for $field: $e');
    }
  }
}

/// Reusable searchable dropdown (returns full object)
class SearchableDropdown extends StatelessWidget {
  final String field;
  final String label;
  final String? initialCode;
  final Function(DropdownItem?)? onChanged;

  const SearchableDropdown({
    super.key,
    required this.field,
    required this.label,
    this.initialCode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DropdownItem>>(
      future: DropdownService.getDropdownItems(field),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text(
            'Error loading $label',
            style: const TextStyle(color: Colors.red),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('No $label options found');
        }

        final items = snapshot.data!;
        final selectedItem = initialCode != null
            ? items.firstWhere(
              (item) => item.code == initialCode,
          orElse: () => items.first,
        )
            : null;

        return DropdownSearch<DropdownItem>(
          items: items,
          selectedItem: selectedItem,
          onChanged: (item) => onChanged?.call(item),
          itemAsString: (item) => item.description, // clean UI
          popupProps: const PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );
      },
    );
  }
}

/// Example usage
class MyForm extends StatelessWidget {
  const MyForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Searchable Dropdown Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SearchableDropdown(
              field: 'MONTH',
              label: 'Select Month 1',
              onChanged: (item) {
                if (item != null) {
                  print("Selected month code: ${item.code}");
                  print("Selected month description: ${item.description}");
                }
              },
            ),
            const SizedBox(height: 16),
            SearchableDropdown(
              field: 'MONTH',
              label: 'Select Month 2',
              initialCode: 'JAN', // preselect January if available
              onChanged: (item) {
                if (item != null) {
                  print("Selected month code: ${item.code}");
                  print("Selected month description: ${item.description}");
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
