// import 'package:flutter/material.dart';
// import 'package:flutter_form_builder/flutter_form_builder.dart';
// import 'package:form_builder_validators/form_builder_validators.dart';
// import 'package:mawa_package/mawa_package.dart';
//
// class PartnerCreateBasicDialog extends StatefulWidget {
//   const PartnerCreateBasicDialog({super.key});
//
//   @override
//   State<PartnerCreateBasicDialog> createState() => _PartnerCreateBasicDialogState();
// }
//
// class _PartnerCreateBasicDialogState extends State<PartnerCreateBasicDialog> {
//   final _formKey = GlobalKey<FormBuilderState>();
//   String _partnerType = 'Individual';
//
//   Future<void> _submit() async {
//     if (_formKey.currentState!.saveAndValidate()) {
//       final values = Map<String, dynamic>.from(_formKey.currentState!.value);
//
//       // Strip hidden fields
//       if (values['partnerType'] == 'Organization') {
//         values.remove('lastName');
//       } else if (values['partnerType'] == 'Individual') {
//         values.remove('groupName');
//       }
//
//       // Strip optional dropdowns if empty
//       for (final key in ['title', 'maritalStatus', 'gender']) {
//         if (values[key] == null || values[key].toString().trim().isEmpty) {
//           values.remove(key);
//         }
//       }
//
//       dynamic response = await Partners.createPartner(
//         body: {
//           JsonPayloads.type: values['partnerType'],
//           JsonPayloads.name1: values['partnerType'] == 'Organization'
//               ? values['groupName']
//               : values['lastName'],
//           JsonPayloads.name2: values['firstName'],
//           JsonPayloads.name3: values['middleName'],
//           if (values.containsKey('title')) JsonPayloads.title: values['title'],
//           if (values.containsKey('maritalStatus'))
//             JsonPayloads.maritalStatus: values['maritalStatus'],
//           if (values.containsKey('gender')) JsonPayloads.gender: values['gender'],
//           JsonPayloads.language: 'EN',
//         },
//       );
//
//       if (response != null) {
//         Navigator.pop(context, true);
//       }
//     }
//   }
//
//   void _clearHiddenFields() {
//     final formState = _formKey.currentState!;
//     if (_partnerType == 'Organization') {
//       formState.fields['lastName']?.didChange(null);
//       formState.fields['gender']?.didChange(null);
//       formState.fields['maritalStatus']?.didChange(null);
//     } else if (_partnerType == 'Individual') {
//       formState.fields['groupName']?.didChange(null);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     final size = MediaQuery.of(context).size;
//     final width = size.width;
//     final height = size.height;
//     final shortestSide = size.shortestSide;
//
//     // Responsive sizing
//     double maxWidth, maxHeight, circleSize, titleFont, bodyFont, timerFont;
//
//     if (width <= 600) {
//       // Mobile
//       maxWidth = width * 0.85;
//       maxHeight = height * 0.45;
//       circleSize = shortestSide * 0.35;
//       titleFont = shortestSide * 0.06;
//       bodyFont = shortestSide * 0.045;
//       timerFont = shortestSide * 0.08;
//     } else if (width <= 1024) {
//       // Tablet
//       maxWidth = width * 0.6;
//       maxHeight = height * 0.5;
//       circleSize = shortestSide * 0.28;
//       titleFont = shortestSide * 0.045;
//       bodyFont = shortestSide * 0.035;
//       timerFont = shortestSide * 0.06;
//     } else {
//       // Desktop
//       maxWidth = width * 0.4;
//       maxHeight = height * 0.5;
//       circleSize = shortestSide * 0.22;
//       titleFont = shortestSide * 0.03;
//       bodyFont = shortestSide * 0.022;
//       timerFont = shortestSide * 0.045;
//     }
//
//     return Center(
//       child: ConstrainedBox(
//         constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
//         child: AlertDialog(
//           title: const Text('Create Partner'),
//           content: FormBuilder(
//             key: _formKey,
//             child: SingleChildScrollView(
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   final isTwoColumn = constraints.maxWidth > 500;
//
//                   Widget fieldWrapper(Widget child) {
//                     return SizedBox(
//                       width: isTwoColumn ? (constraints.maxWidth / 2) - 12 : double.infinity,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
//                         child: child,
//                       ),
//                     );
//                   }
//
//                   final fields = <Widget>[
//                     fieldWrapper(
//                       FormBuilderDropdown<String>(
//                         name: 'partnerType',
//                         initialValue: _partnerType,
//                         decoration: const InputDecoration(labelText: 'Partner Type'),
//                         items: const [
//                           DropdownMenuItem(value: 'Individual', child: Text('Individual')),
//                           DropdownMenuItem(value: 'Organization', child: Text('Organization')),
//                         ],
//                         validator: FormBuilderValidators.required(),
//                         onChanged: (value) {
//                           setState(() {
//                             _partnerType = value ?? 'Individual';
//                             _clearHiddenFields();
//                           });
//                         },
//                       ),
//                     ),
//
//                     if (_partnerType == 'Individual')
//                       fieldWrapper(
//                         FormBuilderTextField(
//                           name: 'lastName',
//                           decoration: const InputDecoration(labelText: 'Last Name'),
//                           validator: FormBuilderValidators.required(),
//                         ),
//                       ),
//
//                     if (_partnerType == 'Organization')
//                       fieldWrapper(
//                         FormBuilderTextField(
//                           name: 'groupName',
//                           decoration: const InputDecoration(labelText: 'Group Name'),
//                           validator: FormBuilderValidators.required(),
//                         ),
//                       ),
//
//                     fieldWrapper(
//                       FormBuilderTextField(
//                         name: 'firstName',
//                         decoration: const InputDecoration(labelText: 'First Name'),
//                         validator: FormBuilderValidators.required(),
//                       ),
//                     ),
//
//                     fieldWrapper(
//                       FormBuilderTextField(
//                         name: 'middleName',
//                         decoration: const InputDecoration(labelText: 'Middle Name'),
//                       ),
//                     ),
//
//                     fieldWrapper(
//                       FormBuilderDropdown<String>(
//                         name: 'title',
//                         decoration: const InputDecoration(labelText: 'Title'),
//                         items: const [
//                           DropdownMenuItem(value: 'Mr', child: Text('Mr')),
//                           DropdownMenuItem(value: 'Ms', child: Text('Ms')),
//                           DropdownMenuItem(value: 'Dr', child: Text('Dr')),
//                         ],
//                       ),
//                     ),
//
//                     if (_partnerType == 'Individual') ...[
//                       fieldWrapper(
//                         FormBuilderDropdown<String>(
//                           name: 'maritalStatus',
//                           decoration: const InputDecoration(labelText: 'Marital Status'),
//                           items: const [
//                             DropdownMenuItem(value: 'Single', child: Text('Single')),
//                             DropdownMenuItem(value: 'Married', child: Text('Married')),
//                           ],
//                         ),
//                       ),
//                       fieldWrapper(
//                         FormBuilderDropdown<String>(
//                           name: 'gender',
//                           decoration: const InputDecoration(labelText: 'Gender'),
//                           items: const [
//                             DropdownMenuItem(value: 'Male', child: Text('Male')),
//                             DropdownMenuItem(value: 'Female', child: Text('Female')),
//                             DropdownMenuItem(value: 'Other', child: Text('Other')),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ];
//
//                   return Wrap(
//                     spacing: 6,
//                     runSpacing: 6,
//                     children: fields,
//                   );
//                 },
//               ),
//             ),
//           ),
//           actions: [
//             LayoutBuilder(
//               builder: (context, constraints) {
//                 final isWide = constraints.maxWidth > 400;
//
//                 if (isWide) {
//                   return Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       TextButton(
//                         onPressed: () => Navigator.pop(context, false),
//                         child: const Text('Cancel'),
//                       ),
//                       ElevatedButton.icon(
//                         onPressed: _submit,
//                         icon: const Icon(Icons.check),
//                         label: const Text('Save'),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         ),
//                       ),
//                     ],
//                   );
//                 } else {
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       OutlinedButton(
//                         onPressed: () => Navigator.pop(context, false),
//                         child: const Text('Cancel'),
//                       ),
//                       const SizedBox(height: 8),
//                       ElevatedButton.icon(
//                         onPressed: _submit,
//                         icon: const Icon(Icons.check),
//                         label: const Text('Save'),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                         ),
//                       ),
//                     ],
//                   );
//                 }
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
