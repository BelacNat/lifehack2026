import 'package:ecohabit/features/inventory/data/inventory_repository.dart';
import 'package:ecohabit/features/inventory/domain/inventory_item.dart';
import 'package:ecohabit/features/inventory/presentation/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adds an inventory item with its measurement', (tester) async {
    final repository = _FakeInventoryRepository();
    await tester.pumpWidget(
      MaterialApp(home: InventoryPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Number of items'),
      '2',
    );
    final measurementField = find.byKey(const Key('measurement-type-field'));
    await tester.ensureVisible(measurementField);
    await tester.tap(measurementField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liquid (millilitres)').last);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final categoryField = find.byKey(const Key('category-field'));
    await tester.ensureVisible(categoryField);
    tester
        .widget<DropdownButtonFormField<InventoryCategory>>(categoryField)
        .onChanged!(InventoryCategory.beverage);
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item name'),
      'Juice',
    );
    final expirationField = find.widgetWithText(
      TextFormField,
      'Expiration date',
    );
    await tester.ensureVisible(expirationField);
    await tester.tap(expirationField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to inventory'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 ml of juice'), findsOneWidget);
    expect(repository.items.single.name, 'juice');
    expect(repository.items.single.category, InventoryCategory.beverage);
  });

  testWidgets('deletes an inventory item from the repository', (tester) async {
    final repository = _FakeInventoryRepository()
      ..items.add(
        InventoryItem(
          id: 7,
          name: 'apples',
          quantity: 2,
          expirationDate: DateTime(2026, 9, 7),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: InventoryPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
    await tester.pumpAndSettle();

    expect(repository.deletedIds, [7]);
    expect(find.textContaining('2 apples'), findsNothing);
  });
}

class _FakeInventoryRepository implements InventoryRepository {
  final items = <InventoryItem>[];
  final deletedIds = <int>[];
  var _nextId = 1;

  @override
  Future<List<InventoryItem>> loadItems() async => List.of(items);

  @override
  Future<InventoryItem> addItem(InventoryItem item) async {
    final saved = InventoryItem(
      id: _nextId++,
      name: item.name,
      quantity: item.quantity,
      measurement: item.measurement,
      category: item.category,
      expirationDate: item.expirationDate,
    );
    items.add(saved);
    return saved;
  }

  @override
  Future<void> deleteItem(int id) async {
    deletedIds.add(id);
    items.removeWhere((item) => item.id == id);
  }
}
