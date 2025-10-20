import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:mawa_api/mawa_api.dart';

/// Model for dropdown items
class DropdownItem {
  final String code;
  final String description;

  DropdownItem({
    required this.code,
    required this.description,
  });

  factory DropdownItem.fromJson(Map<String, dynamic> json) {
    return DropdownItem(
      code: json['code'],
      description: json['description'],
    );
  }

  @override
  String toString() => description; // only show description in UI
}


/// Reusable searchable dropdown (returns full object)
class EmployeeDropdown extends StatelessWidget {
  final String label;
  final String? initialCode;
  final Function(DropdownItem?)? onChanged;

  const EmployeeDropdown({
    super.key,
    required this.label,
    this.initialCode,
    this.onChanged,
  });

  Future<List<DropdownItem>> fetchData() async {
    List<DropdownItem> items = [];
    List<Partner> employees = await PartnerService().search(query: '',role: 'EMPLOYEE');
    items = employees.map((e) {
      return DropdownItem(
        code: e.partnerId ?? '', // Use the partner/employee ID
        description: e.displayName ?? '', // Display name
      );
    }).toList();

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DropdownItem>>(
      future: fetchData(),
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
