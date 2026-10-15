import 'package:flutter/foundation.dart';

@immutable
class MotionInfo {
  const MotionInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.enabled,
    required this.source,
    required this.metadata,
  });

  factory MotionInfo.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return MotionInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      source: json['source'] as String? ?? '',
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.unmodifiable(
              rawMetadata.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const <String, dynamic>{},
    );
  }

  final String id;
  final String name;
  final String category;
  final String description;
  final bool enabled;
  final String source;
  final Map<String, dynamic> metadata;

  double? get durationSeconds {
    final value = metadata['duration_sec'] ?? metadata['duration'];
    return value is num ? value.toDouble() : null;
  }
}
