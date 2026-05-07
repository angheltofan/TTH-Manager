import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/theme/app_theme.dart';
import 'child_form_helpers.dart';

class ChildFormPersonal extends StatelessWidget {
  const ChildFormPersonal({
    super.key,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.ageCtrl,
    required this.birthDate,
    required this.inputDeco,
    required this.onPickDate,
  });

  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController ageCtrl;
  final DateTime? birthDate;
  final InputDecoration inputDeco;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ChildFormField(
                label: 'Prenume',
                required: true,
                child: TextFormField(
                  controller: firstNameCtrl,
                  decoration: inputDeco.copyWith(hintText: 'Ex: Maria'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Prenumele este obligatoriu'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChildFormField(
                label: 'Nume',
                required: true,
                child: TextFormField(
                  controller: lastNameCtrl,
                  decoration:
                      inputDeco.copyWith(hintText: 'Ex: Popescu'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Numele este obligatoriu'
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ChildFormField(
                label: 'Data nașterii',
                child: GestureDetector(
                  onTap: onPickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      readOnly: true,
                      key: ValueKey(birthDate),
                      initialValue:
                          birthDate != null ? formatDate(birthDate!) : '',
                      decoration: inputDeco.copyWith(
                        hintText: 'Selectează data',
                        suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: AppColors.purple),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: ChildFormField(
                label: 'Vârstă',
                child: TextFormField(
                  controller: ageCtrl,
                  decoration: inputDeco.copyWith(hintText: '0'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
