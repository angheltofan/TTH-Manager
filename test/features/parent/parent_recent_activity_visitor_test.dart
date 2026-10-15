import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/parent/domain/parent_dashboard.dart';

void main() {
  group('ParentRecentActivityItem.workshopLabel visitor annotation', () {
    const baseFields = {
      'id': 'a1',
      'childId': 'c1',
      'childFirstName': 'Andrei',
      'childLastName': 'Popescu',
    };

    ParentRecentActivityItem build({
      String? title,
      String? type,
      bool isVisitor = false,
    }) {
      return ParentRecentActivityItem(
        id: baseFields['id'] as String,
        childId: baseFields['childId'] as String,
        childFirstName: baseFields['childFirstName'] as String,
        childLastName: baseFields['childLastName'] as String,
        workshopTitle: title,
        workshopType: type,
        isVisitor: isVisitor,
      );
    }

    test('non-visitor keeps the plain workshop title', () {
      final it = build(title: 'Robotica Marți 16:00');
      expect(it.workshopLabel, 'Robotica Marți 16:00');
    });

    test('visitor appends " (altă grupă)" to the title', () {
      final it = build(title: 'Robotica Marți 16:00', isVisitor: true);
      expect(it.workshopLabel, 'Robotica Marți 16:00 (altă grupă)');
    });

    test('visitor annotation applies to the workshop_type fallback too', () {
      final it = build(type: 'Robotica', isVisitor: true);
      expect(it.workshopLabel, 'Robotica (altă grupă)');
    });

    test('isVisitor defaults to false for backward compatibility', () {
      final it = build(title: 'Lectura');
      expect(it.isVisitor, isFalse);
    });
  });
}
