import 'package:flutter/material.dart';
import '../services/category_icon_service.dart';

class DynamicCategory {
  final String name;
  final String iconName;

  const DynamicCategory({
    required this.name,
    required this.iconName,
  });

  // Get SVG icon path based on category name
  String get iconPath {
    return CategoryIconService.getIconPath(name);
  }

  String get displayName => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicCategory && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}
