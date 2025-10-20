import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mawa_api/mawa_api.dart';
import 'package:mawa_package/mawa_package.dart';
import 'package:mawa_package/services/idnumber_validation.dart';

import '../dropdowns/searchable-dropdown.dart';

class PartnerCreateDialog extends StatefulWidget {
  final dynamic label;
  final dynamic role;

  const PartnerCreateDialog({super.key, required this.label, required this.role});

  @override
  State<PartnerCreateDialog> createState() => _PartnerCreateDialogState();
}

class _PartnerCreateDialogState extends State<PartnerCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController identityNumberController = TextEditingController();
  final TextEditingController orgNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController secondNameController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String partnerType = 'INDIVIDUAL';
  String identityType = 'SA-ID';
  String? _idError;

  @override
  void dispose() {
    identityNumberController.dispose();
    orgNameController.dispose();
    lastNameController.dispose();
    firstNameController.dispose();
    secondNameController.dispose();
    contactNumberController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _idError = null);

    if (!_formKey.currentState!.validate()) return;

    if (identityType == "SA-ID") {
      try {
        final isValid = await IdentityNumberValidation.validateID(
          idType: identityType,
          idNumber: identityNumberController.text,
        );

        if (!isValid) {
          setState(() {
            _idError = "Invalid SA identity number";
          });
          return;
        }
      } catch (e) {
        setState(() {
          _idError = "Failed to validate ID: $e";
        });
        return;
      }
    }

    // Determine name1
    String name1 = (partnerType == "INDIVIDUAL") ? lastNameController.text : orgNameController.text;

    Partner partner = Partner(
      partnerRole: widget.role,
      partnerType: partnerType,
      identityType: identityType,
      identityNumber: identityNumberController.text,
      name1: name1,
      name2: firstNameController.text,
      name3: secondNameController.text,
      contactNumber: contactNumberController.text,
      email: emailController.text,
    );

    final overlay = OverlayWidgets(context: context);
    overlay.showOverlay(SnapShortStaticWidgets.snapshotWaitingIndicator());

    try {
      Partner response = await PartnerService().create(partner);
      Navigator.of(context).pop(response);
    } catch (e) {
      setState(() {
        _idError = "Failed to save partner: $e";
      });
    } finally {
      overlay.dismissOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIndividual = partnerType == "INDIVIDUAL";
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.9 : 1000,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(
                    "New ${widget.label}",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(height: 20),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Partner Type
                        SearchableDropdown(
                          field: 'PARTNER-TYPE',
                          label: 'Partner Type',
                          initialCode: partnerType,
                          onChanged: (code) {
                            partnerType = code!;
                            if (code == "INDIVIDUAL") {
                              identityType = 'SA-ID';
                            } else if (code == "ORGANISATION") {
                              identityType = 'COMPANY-REG-NO';
                            } else {
                              identityType = 'NO-ID-REQUIRED';
                            }
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),

                        // Identity Type
                        SearchableDropdown(
                          field: 'ID-TYPE',
                          label: 'Identity Type',
                          initialCode: identityType,
                          onChanged: (code) {
                            identityType = code!;
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),

                        if (identityType != "NO-ID-REQUIRED") ...[
                          TextFormField(
                            controller: identityNumberController,
                            decoration: InputDecoration(
                              labelText: "Identity Number",
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.credit_card),
                              errorText: _idError,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Enter identity number";
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Organization / Individual fields
                        if (partnerType == "ORGANISATION" || partnerType == "GROUP") ...[
                          TextFormField(
                            controller: orgNameController,
                            decoration: const InputDecoration(
                              labelText: "Organization/Group Name",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            validator: (v) => v!.isEmpty ? "Enter organization/group name" : null,
                          ),
                          const SizedBox(height: 12),
                        ] else if (isIndividual) ...[
                          TextFormField(
                            controller: lastNameController,
                            decoration: const InputDecoration(
                              labelText: "Last Name",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) => v!.isEmpty ? "Enter last name" : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: firstNameController,
                            decoration: const InputDecoration(
                              labelText: "First Name",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => v!.isEmpty ? "Enter first name" : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: secondNameController,
                            decoration: const InputDecoration(
                              labelText: "Second Name",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_2),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Contact Number
                        TextFormField(
                          controller: contactNumberController,
                          decoration: const InputDecoration(
                            labelText: "Contact Number",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),

                        // Email
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: "Email Address",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v != null && v.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                              return "Invalid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Save"),
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
