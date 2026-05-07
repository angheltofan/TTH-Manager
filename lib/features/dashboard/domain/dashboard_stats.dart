class DashboardStats {
  const DashboardStats({
    required this.totalChildren,
    required this.workshopsToday,
    required this.pendingPayments,
    required this.attendanceRate,
  });

  final int totalChildren;
  final int workshopsToday;
  final int pendingPayments;
  final double attendanceRate;

  DashboardStats copyWith({int? pendingPayments}) => DashboardStats(
        totalChildren: totalChildren,
        workshopsToday: workshopsToday,
        pendingPayments: pendingPayments ?? this.pendingPayments,
        attendanceRate: attendanceRate,
      );

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      totalChildren: (map['total_children'] as num?)?.toInt() ?? 0,
      workshopsToday: (map['workshops_today'] as num?)?.toInt() ?? 0,
      pendingPayments: (map['pending_payments'] as num?)?.toInt() ?? 0,
      attendanceRate: (map['attendance_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
