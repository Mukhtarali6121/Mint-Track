import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../services/category_icon_service.dart';

part 'category.g.dart';

@HiveType(typeId: 2)
class Category extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String iconName;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  int position;

  Category({
    required this.name,
    required this.iconName,
    required this.colorValue,
    required this.position,
  });

  // Helper function to get the SVG icon path
  String getIconPath(String iconName) {
    return CategoryIconService.getIconPath(iconName);
  }
  // Get SVG icon path based on category name
  String get iconPath => getIconPath(iconName);

  Color get color => Color(colorValue);

  String get displayName => name;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
      'colorValue': colorValue,
      'position': position,
    };
  }

  // Create from Map (Firestore format)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      name: map['name'] ?? '',
      iconName: map['iconName'] ?? 'category',
      colorValue: map['colorValue'] ?? Colors.blue.value,
      position: map['position'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          iconName == other.iconName &&
          colorValue == other.colorValue &&
          position == other.position;

  @override
  int get hashCode =>
      name.hashCode ^
      iconName.hashCode ^
      colorValue.hashCode ^
      position.hashCode;

  @override
  String toString() => name;
}
