// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:dropdown_search/dropdown_search.dart';
// import 'package:mawa_api/mawa_api.dart';
//
// import '../dialogs/partner-create-dialog.dart';
//
// /// Model for dropdown items
// class DropdownItem {
//   final String code;
//   final String description;
//
//   DropdownItem({
//     required this.code,
//     required this.description,
//   });
//
//   factory DropdownItem.fromJson(Map<String, dynamic> json) {
//     return DropdownItem(
//       code: json['code'],
//       description: json['description'],
//     );
//   }
//
//   @override
//   String toString() => description; // only show description in UI
// }
//
// /// Reusable searchable dropdown (returns full object)
// class PartnerSearchCreateDropdown extends StatefulWidget {
//   final String label;
//   final String? initialCode;
//   final Function(DropdownItem?)? onChanged;
//
//   const PartnerSearchCreateDropdown({
//     super.key,
//     required this.label,
//     this.initialCode,
//     this.onChanged,
//   });
//
//   @override
//   State<PartnerSearchCreateDropdown> createState() =>
//       _PartnerSearchCreateDropdownState();
// }
//
// class _PartnerSearchCreateDropdownState
//     extends State<PartnerSearchCreateDropdown> {
//   Future<List<DropdownItem>> fetchData() async {
//     List<DropdownItem> items = [];
//     List<Partner> employees =
//         await PartnerService().search(query: '', role: 'EMPLOYEE');
//     items = employees.map((e) {
//       return DropdownItem(
//         code: e.partnerId ?? '', // Use the partner/employee ID
//         description: e.name1, // Display name
//       );
//     }).toList();
//
//     return items;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<List<DropdownItem>>(
//       future: fetchData(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         } else if (snapshot.hasError) {
//           return Text(
//             'Error loading ${widget.label}',
//             style: const TextStyle(color: Colors.red),
//           );
//         } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return ListTile(
//             leading: const Icon(Icons.add),
//             title: Text('Create ${widget.label}'),
//             subtitle: const Text('Tap To Create'),
//             onTap: () async {
//               final partner = await showDialog(
//                 context: context,
//                 builder: (ctx) => PartnerCreateDialog(label: widget.label,role: '',),
//               );
//
//               if (partner != null) {
//                 setState(() {
//                 });
//                 // field.didChange(partner);
//                 widget.onChanged?.call(partner);
//                 Navigator.of(context).pop(); // close dropdown
//               }
//             },
//           );
//         }
//
//         final items = snapshot.data!;
//         final selectedItem = widget.initialCode != null
//             ? items.firstWhere(
//                 (item) => item.code == widget.initialCode,
//                 orElse: () => items.first,
//               )
//             : null;
//
//         return DropdownSearch<DropdownItem>(
//           items: items,
//           selectedItem: selectedItem,
//           onChanged: (item) => widget.onChanged?.call(item),
//           itemAsString: (item) => item.description, // clean UI
//           popupProps: const PopupProps.menu(
//             showSearchBox: true,
//             searchFieldProps: TextFieldProps(
//               decoration: InputDecoration(
//                 hintText: 'Search...',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ),
//           dropdownDecoratorProps: DropDownDecoratorProps(
//             dropdownSearchDecoration: InputDecoration(
//               labelText: widget.label,
//               border: const OutlineInputBorder(),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
