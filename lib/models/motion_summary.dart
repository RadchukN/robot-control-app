class MotionCategory {
  const MotionCategory({required this.name, required this.count});

  factory MotionCategory.fromJson(Map<String, dynamic> json) =>
      MotionCategory(name: json['name'] as String, count: json['count'] as int);

  final String name;
  final int count;
}

class MotionSummary {
  const MotionSummary({
    required this.total,
    required this.enabled,
    required this.disabled,
    required this.categories,
  });

  factory MotionSummary.fromJson(Map<String, dynamic> json) => MotionSummary(
    total: json['total'] as int,
    enabled: json['enabled'] as int,
    disabled: json['disabled'] as int,
    categories: (json['categories'] as List<dynamic>)
        .map((item) => MotionCategory.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final int total;
  final int enabled;
  final int disabled;
  final List<MotionCategory> categories;
}
