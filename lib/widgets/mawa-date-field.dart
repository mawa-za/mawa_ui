import 'package:flutter/material.dart';

class MawaDateField extends StatefulWidget {
  final String label;
  final DateTime? initialValue;
  final ValueChanged<DateTime?>? onChanged;
  final FormFieldValidator<DateTime?>? validator;

  const MawaDateField({
    super.key,
    required this.label,
    this.initialValue,
    this.onChanged,
    this.validator,
  });

  @override
  State<MawaDateField> createState() => _MawaDateFieldState();
}

class _MawaDateFieldState extends State<MawaDateField> {
  DateTime? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _value ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );

    if (picked != null) {
      setState(() => _value = picked);
      widget.onChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime?>(
      initialValue: _value,
      validator: widget.validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              onPressed: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: widget.label,
                  errorText: field.errorText,
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  _value == null
                      ? "Select date"
                      : "${_value!.year}-${_value!.month.toString().padLeft(2, '0')}-${_value!.day.toString().padLeft(2, '0')}",
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
