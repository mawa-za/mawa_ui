import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:mawa_api/mawa_api.dart';


// Model for dropdown items
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
  String toString() => description; // used for display/search
}

// Service to fetch and cache dropdown items per field
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
    final response = await FieldOptionService().getOptions(field);
    try {
      final List<dynamic> data = response;
      return data.map((json) => DropdownItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load dropdown data for $field');
    }
  }
}

// Reusable searchable dropdown returning code
class SearchableDropdown extends StatelessWidget {
  final String field;
  final String label;
  final String? initialCode;
  final Function(String?)? onChanged;

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
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No items found');
        }

        final items = snapshot.data!;
        final selectedItem = items.firstWhere(
              (item) => item.code == initialCode,
          orElse: () => items.first,
        );

        return DropdownSearch<DropdownItem>(
          items: items,
          selectedItem: selectedItem,
          onChanged: (item) {
            onChanged?.call(item?.code); // return only code
          },
          itemAsString: (item) => item.description,
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

// Example usage
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
              onChanged: (code) => print('Selected month 1 code: $code'),
            ),
            const SizedBox(height: 16),
            SearchableDropdown(
              field: 'MONTH',
              label: 'Select Month 2',
              onChanged: (code) => print('Selected month 2 code: $code'),
            ),
          ],
        ),
      ),
    );
  }
}
