import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/assets/app_icons.dart';

/// Labelled text input with the app's styling. The caller owns (and
/// disposes) the controller.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.autofillHints,
    this.inputFormatters,
    this.errorText,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  final ValueChanged<String>? onChanged;

  /// Read-only fields that open a picker on tap (e.g. dates).
  final bool readOnly;
  final VoidCallback? onTap;

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Password-style field with a show/hide toggle.
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;

  /// Server-side error for this field (e.g. from ApiException.fieldErrors).
  final String? errorText;
  final int maxLines;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      obscureText: _hidden,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show' : 'Hide',
                icon: Icon(_hidden ? AppIcons.visibility : AppIcons.visibilityOff),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
