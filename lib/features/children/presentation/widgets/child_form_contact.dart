import 'package:flutter/material.dart';

import 'child_form_helpers.dart';

class ChildFormContact extends StatelessWidget {
  const ChildFormContact({
    super.key,
    required this.parentNameCtrl,
    required this.parentPhoneCtrl,
    required this.inputDeco,
  });

  final TextEditingController parentNameCtrl;
  final TextEditingController parentPhoneCtrl;
  final InputDecoration inputDeco;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChildFormField(
          label: 'Nume părinte / tutore',
          child: TextFormField(
            controller: parentNameCtrl,
            decoration: inputDeco.copyWith(hintText: 'Ex: Ana Popescu'),
          ),
        ),
        const SizedBox(height: 14),
        ChildFormField(
          label: 'Telefon',
          child: TextFormField(
            controller: parentPhoneCtrl,
            decoration: inputDeco.copyWith(hintText: 'Ex: 07XX XXX XXX'),
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }
}
