import 'package:flutter/material.dart';

class ChildrenTableHeader extends StatelessWidget {
  const ChildrenTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.outline,
      letterSpacing: 0.5,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(flex: 3, child: Text('NUME COPIL', style: style)),
          Expanded(flex: 4, child: Text('ATELIERE', style: style)),
          Expanded(flex: 2, child: Text('ULTIMA PREZENȚĂ', style: style)),
          SizedBox(width: 80, child: Text('STATUS', style: style)),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}
