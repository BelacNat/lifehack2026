import 'package:ecohabit/features/inventory/domain/inventory_item.dart';
import 'package:ecohabit/features/inventory/domain/inventory_ocr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = InventoryOcrParser();
  final today = DateTime(2026, 8, 29);

  test('parses quantities, units, categories, and ignores receipt totals', () {
    final items = parser.parse(
      '2 x Apples\n500 ml Milk 3.20\n1kg Rice 8.50\nTOTAL 11.70',
      today: today,
    );

    expect(items, hasLength(3));
    expect(items[0].name, 'apples');
    expect(items[0].quantity, 2);
    expect(items[0].category, InventoryCategory.produce);
    expect(items[1].name, 'milk');
    expect(items[1].quantity, 500);
    expect(items[1].measurement, ItemMeasurement.liquid);
    expect(items[2].quantity, 1000);
    expect(items[2].measurement, ItemMeasurement.weight);
  });

  test('deduplicates repeated OCR lines', () {
    final items = parser.parse('Bread\nbread\nSUBTOTAL', today: today);
    expect(items.map((item) => item.name), ['bread']);
  });

  test('merges supported image labels and ignores generic labels', () {
    final items = parser.mergeImageLabels(
      parser.parse('1 Milk', today: today),
      ['Apple', 'Fruit', 'Food', 'Milk'],
      today: today,
    );

    expect(items.map((item) => item.name), ['milk', 'apple']);
    expect(items.last.category, InventoryCategory.produce);
  });

  test('accepts specific vision foods while filtering generic labels', () {
    final items = parser.mergeImageLabels(
      const [],
      ['red delicious apple', 'Fruit', 'Food'],
      today: today,
    );

    expect(items.map((item) => item.name), ['red delicious apple']);
  });
}
