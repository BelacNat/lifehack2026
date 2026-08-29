import 'package:ecohabit/features/inventory/data/inventory_repository.dart';
import 'package:ecohabit/features/inventory/data/inventory_ocr_service.dart';
import 'package:ecohabit/features/inventory/domain/inventory_item.dart';
import 'package:ecohabit/features/inventory/domain/inventory_ocr_detection.dart';
import 'package:ecohabit/features/inventory/domain/shopping_list_checker.dart';
import 'package:ecohabit/features/inventory/presentation/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scans, reviews, and adds multiple inventory items',
      (tester) async {
    final repository = _FakeInventoryRepository();
    final ocr = _FakeInventoryOcrService(
      const InventoryRecognitionResult(
        text: '500 ml Milk',
        imageDetections: [InventoryOcrDetection(name: 'Apple', quantity: 3)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(repository: repository, ocrService: ocr),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from photos'));
    await tester.pumpAndSettle();

    expect(find.text('Review 2 detected items'), findsOneWidget);
    expect(find.text('3 apple'), findsOneWidget);
    expect(find.text('500 ml of milk'), findsOneWidget);
    await tester.tap(find.text('Add selected (2)'));
    await tester.pumpAndSettle();

    expect(repository.items, hasLength(2));
    expect(repository.items.firstWhere((item) => item.name == 'apple').quantity,
        3);
    expect(find.textContaining('2 items added'), findsOneWidget);
  });

  testWidgets('scanner is primary and text input starts collapsed',
      (tester) async {
    final repository = _FakeInventoryRepository();
    final ocr = _FakeInventoryOcrService(
      const InventoryRecognitionResult(text: '', imageDetections: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(repository: repository, ocrService: ocr),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('primary-scan-button')), findsOneWidget);
    expect(find.byKey(const Key('shopping-list-text-field')), findsNothing);

    await tester.tap(find.text('Enter as text'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shopping-list-text-field')), findsOneWidget);
    expect(find.text('Check before I shop'), findsOneWidget);
  });

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

  testWidgets('shows a description warning directly below the check button',
      (tester) async {
    final repository = _FakeInventoryRepository()
      ..items.add(
        InventoryItem(
          id: 8,
          name: 'butter',
          quantity: 250,
          measurement: ItemMeasurement.weight,
          expirationDate: DateTime(2026, 9, 20),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: InventoryPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter as text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('shopping-list-text-field')),
      'a stick of butter',
    );
    tester.testTextInput.hide();
    await tester.tap(find.text('Check before I shop'));
    await tester.pumpAndSettle();

    final buttonY = tester.getBottomLeft(find.text('Check before I shop')).dy;
    final warningY =
        tester.getTopLeft(find.text('WAIT! Check your kitchen first')).dy;
    expect(warningY, greaterThan(buttonY));
    expect(find.textContaining('250 g of butter'), findsOneWidget);
  });

  testWidgets('skips a duplicate and records the avoided purchase',
      (tester) async {
    final repository = _FakeInventoryRepository()
      ..items.add(
        InventoryItem(
          id: 8,
          name: 'butter',
          quantity: 250,
          measurement: ItemMeasurement.weight,
          expirationDate: DateTime(2026, 9, 20),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: InventoryPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter as text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('shopping-list-text-field')),
      'a stick of butter',
    );
    await tester.tap(find.text('Check before I shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I’ll skip this'));
    await tester.pumpAndSettle();

    expect(repository.avoidedPurchases, hasLength(1));
    expect(repository.avoidedPurchases.single.item.name, 'butter');
    expect(
      find.text('Great choice — all duplicate purchases were removed.'),
      findsOneWidget,
    );
    expect(find.textContaining('purchase avoided!'), findsOneWidget);
    final shoppingField = tester.widget<TextField>(
      find.byKey(const Key('shopping-list-text-field')),
    );
    expect(shoppingField.controller!.text, isEmpty);
  });

  testWidgets('ignores a possible duplicate without changing the list',
      (tester) async {
    final repository = _FakeInventoryRepository()
      ..items.add(
        InventoryItem(
          id: 9,
          name: 'milk',
          quantity: 500,
          measurement: ItemMeasurement.liquid,
          expirationDate: DateTime(2026, 9, 20),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: InventoryPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter as text'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('shopping-list-text-field')),
      'whole milk',
    );
    await tester.tap(find.text('Check before I shop'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Possible duplicate'), findsOneWidget);
    await tester.tap(find.text('Ignore warning'));
    await tester.pumpAndSettle();

    expect(repository.avoidedPurchases, isEmpty);
    final shoppingField = tester.widget<TextField>(
      find.byKey(const Key('shopping-list-text-field')),
    );
    expect(shoppingField.controller!.text, 'whole milk');
    expect(find.textContaining('stays on your list'), findsOneWidget);
  });
}

class _FakeInventoryOcrService implements InventoryOcrService {
  _FakeInventoryOcrService(this.result);

  final InventoryRecognitionResult result;

  @override
  bool get isSupported => true;

  @override
  Future<InventoryRecognitionResult?> recognize(
    InventoryImageSource source,
  ) async =>
      result;
}

class _FakeInventoryRepository implements InventoryRepository {
  final items = <InventoryItem>[];
  final deletedIds = <int>[];
  final avoidedPurchases = <ShoppingSuggestion>[];
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

  @override
  Future<void> recordAvoidedPurchase(ShoppingSuggestion suggestion) async {
    avoidedPurchases.add(suggestion);
  }
}
