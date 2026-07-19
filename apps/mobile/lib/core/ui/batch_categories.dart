import 'package:flutter/material.dart';

final class BatchCategoryOption {
  const BatchCategoryOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

abstract final class BatchCategories {
  static const values = <BatchCategoryOption>[
    BatchCategoryOption(label: 'Овощи', icon: Icons.eco_outlined),
    BatchCategoryOption(label: 'Фрукты', icon: Icons.apple_outlined),
    BatchCategoryOption(
      label: 'Варенье',
      icon: Icons.breakfast_dining_outlined,
    ),
    BatchCategoryOption(label: 'Соусы', icon: Icons.water_drop_outlined),
    BatchCategoryOption(label: 'Грибы', icon: Icons.forest_outlined),
    BatchCategoryOption(label: 'Напитки', icon: Icons.local_drink_outlined),
    BatchCategoryOption(label: 'Заморозка', icon: Icons.ac_unit_outlined),
    BatchCategoryOption(label: 'Сушка', icon: Icons.wb_sunny_outlined),
    BatchCategoryOption(label: 'Другое', icon: Icons.inventory_2_outlined),
  ];

  static IconData iconFor({required String name, required String category}) {
    final normalized = '$name $category'.toLowerCase();
    if (normalized.contains('огур')) return Icons.eco_outlined;
    if (normalized.contains('клубник') || normalized.contains('ягод')) {
      return Icons.local_florist_outlined;
    }
    for (final item in values) {
      if (item.label == category) return item.icon;
    }
    return Icons.inventory_2_outlined;
  }

  static bool isPreset(String category) =>
      values.any((item) => item.label == category);

  static String unitFor(String category) => switch (category) {
    'Овощи' || 'Фрукты' => 'шт.',
    'Варенье' || 'Соусы' || 'Напитки' => 'мл',
    'Грибы' || 'Заморозка' || 'Сушка' => 'г',
    _ => 'шт.',
  };
}
