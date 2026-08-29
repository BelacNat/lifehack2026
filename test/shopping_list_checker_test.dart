import 'package:ecohabit/features/inventory/domain/inventory_item.dart';
import 'package:ecohabit/features/inventory/domain/shopping_list_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final checker = ShoppingListChecker();

  test('finds items already in the inventory', () {
    final result = checker.check(
      '12 eggs, 1 ml of milk, 1 bag of bacon, 1 box of spaghetti',
      const [
        InventoryItem(name: 'eggs', quantity: 6),
        InventoryItem(
          name: 'milk',
          quantity: 1,
          measurement: ItemMeasurement.liquid,
        ),
      ],
    );
    expect(result.items, hasLength(4));
    expect(result.suggestions, hasLength(2));
    expect(result.suggestions.first.message, contains('6 eggs'));
    expect(result.suggestions.last.covered, isTrue);
  });

  test('combines duplicate shopping-list entries', () {
    final result = checker.check('2 eggs\n3 eggs, milk', const []);
    expect(result.items, hasLength(2));
    expect(result.items.first.quantity, 5);
  });

  test('preserves units and natural wording in feedback', () {
    final result = checker.check(
      '1 ml of milk',
      const [
        InventoryItem(
          name: 'milk',
          quantity: 1,
          measurement: ItemMeasurement.liquid,
        ),
      ],
    );

    expect(result.items.single.measurement, ItemMeasurement.liquid);
    expect(result.suggestions.single.covered, isTrue);
    expect(result.suggestions.single.message, contains('1 ml of milk'));
    expect(result.suggestions.single.message, isNot(contains('carton')));
  });

  test('matches packaging descriptions across different measurements', () {
    final result = checker.check(
      'a stick of butter',
      const [
        InventoryItem(
          name: 'Butter',
          quantity: 250,
          measurement: ItemMeasurement.weight,
        ),
      ],
    );

    expect(result.items.single.name, 'butter');
    expect(result.suggestions, hasLength(1));
    expect(result.suggestions.single.message, contains('250 g of Butter'));
  });

  test('matches number words, shopping verbs, and varied containers', () {
    final result = checker.check(
      'please get two jars of tomato sauce, pick up a loaf of bread',
      const [
        InventoryItem(name: 'tomato sauce', quantity: 1),
        InventoryItem(name: 'bread', quantity: 1),
      ],
    );

    expect(result.suggestions, hasLength(2));
  });
}
