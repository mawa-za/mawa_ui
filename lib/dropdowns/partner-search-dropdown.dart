import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:mawa_api/mawa_api.dart';
import 'package:mawa_package/mawa_package.dart';
import '../dialogs/partner-create-basic-dialog.dart';
import '../dialogs/partner-create-dialog.dart';

class PartnerSearchDropdown extends StatefulWidget {
  final Function(Partner)? onChanged;
  final String label;
  final String role;
  final bool preload;
  final String? Function(Partner?)? validator;

  const PartnerSearchDropdown({
    super.key,
    this.onChanged,
    this.preload = true,
    this.label = 'Customer',
    this.role = 'CUSTOMER',
    this.validator,
  });

  @override
  State<PartnerSearchDropdown> createState() => _PartnerSearchDropdownState();
}

class _PartnerSearchDropdownState extends State<PartnerSearchDropdown> {
  List<Map<String, dynamic>> response = [];
  Partner? partner;

  Future<List<Partner>> fetchData(String filter) async {
    if (filter.isEmpty && widget.preload == false) return [];
    List<Partner> list = await PartnerService().search(query: filter, role: '');
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<Partner>(
      validator: widget.validator ??
          (value) {
            if (value == null) {
              return 'Please select a ${widget.label}';
            }
            return null;
          },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownSearch<Partner>(
              asyncItems: (String filter) => fetchData(filter),
              selectedItem: partner,
              dropdownBuilder: (context, item) {
                return item == null
                    ? ListTile(title: Text('Select ${widget.label}'))
                    : ListTile(
                        title: Text(item.displayName),
                        subtitle: Text(
                            '${item.identityType ?? ''} : ${item.identityNumber ?? ''}'),
                      );
              },
              onChanged: (data) {
                if (data != null) {
                  final selected = data;
                  setState(() => partner = selected);
                  field.didChange(selected);
                  widget.onChanged?.call(selected);
                }
              },
              popupProps: _buildPopupProps(field),
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: widget.label,
                  border: const OutlineInputBorder(),
                  errorText: field.errorText,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  PopupProps<Partner> _buildPopupProps(FormFieldState<Partner> field) {
    return PopupProps.dialog(
      showSearchBox: true,
      searchDelay: Duration.zero,
      isFilterOnline: true,
      searchFieldProps: const TextFieldProps(autofocus: true),
      itemBuilder: (context, item, isSelected) => ListTile(
        selected: isSelected,
        title: Text(item.displayName),
        subtitle:
            Text('${item.identityType ?? ''} : ${item.identityNumber ?? ''}'),
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      ),
      emptyBuilder: (context, searchText) {
        if (searchText.isEmpty && widget.preload == false) {
          return const _InfoMessage('Type to search');
        } else if (searchText.length > 0 && response.isEmpty) {
          return Column(
            children: [
              const _InfoMessage('No Record Found'),
              ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('New ${widget.label}'),
                  subtitle: const Text('Tap to add new'),
                  onTap: () async {
                    final newPartner = await showDialog(
                      context: context,
                      builder: (ctx) => PartnerCreateDialog(
                        label: widget.label,
                        role: widget.role,
                      ),
                    );

                    if (newPartner != null) {
                      setState(() {
                        partner = newPartner; // ✅ set as selected
                      });
                      field.didChange(newPartner);
                      widget.onChanged?.call(newPartner);

                      // Force DropdownSearch to reload its asyncItems

                      Navigator.of(context).pop(); // close dropdown popup
                    }
                  }),
            ],
          );
        }
        return const Center(child: Text('No Data Found'));
      },
      loadingBuilder: (context, _) =>
          Center(child: SnapShortStaticWidgets.snapshotWaitin()),
      errorBuilder: (context, _, __) =>
           Center(child: SnapShortStaticWidgets.snapshotError()),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  final String message;
  const _InfoMessage(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
      ),
    );
  }
}
