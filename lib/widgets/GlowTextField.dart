import 'package:flutter/material.dart';

class GlowTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onEditingComplete;

  const GlowTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onEditingComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      validator: validator,
      onEditingComplete: () {
        if (onEditingComplete != null) {
          onEditingComplete!();
        } else {
          if (textInputAction == TextInputAction.next) {
            FocusScope.of(context).nextFocus();
          } else if (textInputAction == TextInputAction.done) {
            FocusScope.of(context).unfocus();
          }
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
