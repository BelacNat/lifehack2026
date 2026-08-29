import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard/presentation/dashboard_summary_controller.dart';
import '../../quests/data/mock_leaderboard_data.dart' show currentUserId;
import '../../quests/data/points_service.dart';
import '../../quests/data/quest_points_store.dart';
import '../../quests/data/quest_progress_store.dart';
import '../../quests/data/streak_service.dart';
import '../../quests/domain/points_calculator.dart';
import '../data/expiry_notification_service.dart';
import '../data/fridge_items_controller.dart';
import '../data/fridge_repository.dart';
import '../data/openai_recipe_service.dart';
import '../data/rescue_recipes_controller.dart';
import '../domain/fridge_item.dart';
import '../domain/recipe_suggestion.dart';
import 'widgets/recipe_detail_page.dart';
import 'widgets/recipe_image.dart';

String _categoryLabel(String category) {
  if (category.isEmpty) return 'Other';
  return '${category[0].toUpperCase()}${category.substring(1)}';
}

class FridgePage extends StatefulWidget {
  const FridgePage({
    super.key,
    this.recipeService,
    this.fridgeRepository,
    this.initialTab = 0,
  });

  final RecipeSuggestionService? recipeService;
  final FridgeRepository? fridgeRepository;

  /// 0 = Expiring soon, 1 = Rescue recipes.
  final int initialTab;

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  static const _notifiedExpiryItemsKey = 'fridge_notified_expiry_items_v1';
  static const _notificationTimeKey = 'fridge_notification_time_minutes_v1';
  static const _defaultNotificationTimeMinutes = 9 * 60;

  late final RecipeSuggestionService _recipeService;
  late final FridgeRepository _fridgeRepository;
  final ExpiryNotificationService _notificationService =
      const ExpiryNotificationService();
  final PointsService _pointsService = const PointsService();
  final StreakService _streakService = const StreakService();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  Timer? _expiryCheckTimer;
  List<FridgeItem> _items = const [];
  // Edge-detection for the streak bump: true once the current "everything
  // expiring today is cleared" state has already been counted, so it isn't
  // re-counted on every reload — reset the moment a new today-item appears.
  bool _streakCountedForCurrentClear = false;

  List<RecipeSuggestion> _recipes = const [];
  String? _loadError;
  String? _recipeError;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _notificationStatusReady = false;
  int _notificationTimeMinutes = _defaultNotificationTimeMinutes;
  ExpiryNotificationPermission _notificationPermission =
      ExpiryNotificationPermission.unsupported;

  @override
  void initState() {
    super.initState();
    _recipeService = widget.recipeService ?? const OpenAiRecipeService();
    _fridgeRepository =
        widget.fridgeRepository ?? const SupabaseFridgeRepository();
    _initializeNotifications();
    _loadItems();
    _expiryCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadItems(refreshRecipes: false, showLoading: false),
    );
  }

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    final savedTime = await _preferences.getInt(_notificationTimeKey);
    final permission = await _notificationService.currentPermission();
    if (!mounted) return;
    setState(() {
      _notificationTimeMinutes = savedTime?.clamp(0, (24 * 60) - 1).toInt() ??
          _defaultNotificationTimeMinutes;
      _notificationPermission = permission;
      _notificationStatusReady = true;
    });
    if (permission == ExpiryNotificationPermission.granted &&
        _items.isNotEmpty) {
      await _notifyNewExpiringItems(_items);
    }
  }

  Future<void> _enableNotifications() async {
    final permission = await _notificationService.requestPermission();
    if (!mounted) return;
    setState(() => _notificationPermission = permission);

    if (permission == ExpiryNotificationPermission.granted) {
      _showMessage('Expiry notifications enabled.');
      await _notifyNewExpiringItems(_items);
    } else if (permission == ExpiryNotificationPermission.denied) {
      _showMessage('Notifications are blocked in your browser settings.');
    }
  }

  Future<void> _selectNotificationTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _notificationTimeMinutes ~/ 60,
        minute: _notificationTimeMinutes % 60,
      ),
      helpText: 'Choose your expiry reminder time',
    );
    if (selected == null || !mounted) return;

    final minutes = selected.hour * 60 + selected.minute;
    await _preferences.setInt(_notificationTimeKey, minutes);
    if (!mounted) return;
    setState(() => _notificationTimeMinutes = minutes);
    _showMessage('Daily reminder time updated.');
    await _notifyNewExpiringItems(_items);
  }

  Future<void> _notifyNewExpiringItems(List<FridgeItem> items) async {
    if (_notificationPermission != ExpiryNotificationPermission.granted) {
      return;
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    if (currentMinutes != _notificationTimeMinutes) return;

    final expiringItems = items.where((item) {
      final status = item.statusAt(now);
      return !item.isConsumed &&
          (status == FridgeItemStatus.today || status == FridgeItemStatus.soon);
    }).toList(growable: false);
    if (expiringItems.isEmpty) return;

    final notified =
        (await _preferences.getStringList(_notifiedExpiryItemsKey) ?? const [])
            .toSet();
    final newItems = expiringItems
        .where((item) => !notified.contains(_expiryNotificationKey(item)))
        .toList(growable: false);
    if (newItems.isEmpty) return;

    final names = newItems.take(3).map((item) => item.name).join(', ');
    final remainingCount = newItems.length - 3;
    final body = remainingCount > 0
        ? '$names and $remainingCount more need rescuing soon.'
        : '$names ${newItems.length == 1 ? 'needs' : 'need'} rescuing soon.';

    try {
      _notificationService.show(
        title: newItems.length == 1
            ? '${newItems.first.name} expires soon'
            : '${newItems.length} foods expire soon',
        body: body,
        tag: 'fridge-expiry-${newItems.map((item) => item.id).join('-')}',
      );
      notified.addAll(newItems.map(_expiryNotificationKey));
      await _preferences.setStringList(
        _notifiedExpiryItemsKey,
        notified.take(300).toList(growable: false),
      );
    } catch (_) {
      // A later refresh will retry if the browser could not show it.
    }
  }

  String _expiryNotificationKey(FridgeItem item) {
    return '${item.id}:${item.expiresOn?.toIso8601String() ?? 'none'}';
  }

  Future<void> _loadItems({
    bool refreshRecipes = true,
    bool showLoading = true,
  }) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final items = await _fridgeRepository.fetchItems();
      FridgeItemsController.items.value = items;
      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
      await _notifyNewExpiringItems(items);
      if (refreshRecipes) await _generateRecipes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load your fridge. Check your connection.';
      });
    }
  }

  List<FridgeItem> get _visibleItems {
    final now = DateTime.now();
    final filtered = _items.where((item) {
      final status = item.statusAt(now);
      return status == FridgeItemStatus.today ||
          status == FridgeItemStatus.soon;
    }).toList();

    filtered.sort((a, b) {
      if (a.expiresOn == null) return 1;
      if (b.expiresOn == null) return -1;
      return a.expiresOn!.compareTo(b.expiresOn!);
    });
    return filtered;
  }

  int get _rescueSoonCount {
    return _visibleItems.length;
  }

  int get _recipePriorityCount {
    final now = DateTime.now();
    return _items.where((item) {
      final status = item.statusAt(now);
      return status == FridgeItemStatus.today ||
          status == FridgeItemStatus.soon;
    }).length;
  }

  List<FridgeItem> get _activeIngredients {
    final now = DateTime.now();
    final ingredients = _items.where((item) {
      return !item.isConsumed && item.statusAt(now) != FridgeItemStatus.overdue;
    }).toList();

    ingredients.sort((a, b) {
      if (a.expiresOn == null) return 1;
      if (b.expiresOn == null) return -1;
      return a.expiresOn!.compareTo(b.expiresOn!);
    });
    return ingredients;
  }

  /// True once nothing expiring today remains unconsumed — the day's
  /// zero-waste streak condition.
  bool get _allUrgentItemsCleared {
    final now = DateTime.now();
    return !_items.any((item) {
      if (item.isConsumed) return false;
      return item.statusAt(now) == FridgeItemStatus.today;
    });
  }

  /// Records a zero-waste day after a qualifying sustainability action.
  /// The server RPC is the final guard that makes this idempotent per date.
  Future<void> _maybeBumpStreak() async {
    if (!_allUrgentItemsCleared) {
      _streakCountedForCurrentClear = false;
      return;
    }
    if (_streakCountedForCurrentClear) return;

    _streakCountedForCurrentClear = true;
    try {
      await _streakService.bumpDailyStreak();
      DashboardSummaryController.requestRefresh();
      unawaited(QuestProgressStore.recordZeroWasteDay());
    } catch (_) {
      _streakCountedForCurrentClear = false;
    }
  }

  Future<void> _toggleConsumed(FridgeItem item) async {
    final nextValue = !item.isConsumed;
    setState(() {
      _items = _items
          .map(
            (candidate) => candidate.id == item.id
                ? candidate.copyWith(isConsumed: nextValue)
                : candidate,
          )
          .toList(growable: false);
    });
    FridgeItemsController.items.value = _items;

    try {
      await _fridgeRepository.setConsumed(
        id: item.id,
        isConsumed: nextValue,
      );

      var message = nextValue ? 'Marked as consumed.' : 'Moved back to fridge.';
      if (nextValue) {
        unawaited(QuestProgressStore.recordFridgeActivityToday());
      }
      final rescuedBeforeExpiry = nextValue &&
          item.statusAt(DateTime.now()) != FridgeItemStatus.overdue;
      if (rescuedBeforeExpiry) {
        final points = PointsCalculator.pointsForCategory(item.category);
        try {
          await _pointsService.awardFoodRescuePoints(
            itemName: item.name,
            points: points,
          );
          message = 'Marked as consumed. +$points pts!';
        } catch (_) {
          // Points are a bonus on top of the consumed-state update above,
          // which already succeeded — don't fail the whole action for it.
        }
        // Reflect the new points on the leaderboard immediately, without
        // waiting for a full leaderboard reload.
        unawaited(QuestPointsStore.addBonusPoints(currentUserId, points));
        unawaited(QuestProgressStore.recordItemRescued());

        await _maybeBumpStreak();
      }
      if (mounted) _showMessage(message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (candidate) => candidate.id == item.id
                  ? candidate.copyWith(isConsumed: item.isConsumed)
                  : candidate,
            )
            .toList(growable: false);
      });
      _showMessage('Could not update this item. Please try again.');
    }
  }

  Future<void> _generateRecipes() async {
    if (_activeIngredients.isEmpty) {
      RescueRecipesController.recipes.value = const [];
      setState(() {
        _recipeError = 'No safe, available ingredients were found.';
        _recipes = const [];
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _recipeError = null;
    });
    try {
      final recipes = await _recipeService.generate(
        ingredients: _activeIngredients,
      );
      RescueRecipesController.recipes.value = recipes;
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _recipeError = null;
      });
    } on RecipeSuggestionException catch (error) {
      if (mounted) setState(() => _recipeError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _recipeError = 'Something went wrong while creating recipes.';
        });
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _openRecipe(RecipeSuggestion recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RecipeDetailPage(recipe: recipe),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F8F4),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Rescue My Fridge',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Eat what you have. Waste less.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.schedule_rounded),
                text: 'Expiring soon',
              ),
              Tab(
                icon: Icon(Icons.auto_awesome_rounded),
                text: 'Rescue recipes',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _loadItems,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_notificationStatusReady &&
                      _notificationPermission !=
                          ExpiryNotificationPermission.unsupported)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _ExpiryNotificationBanner(
                          permission: _notificationPermission,
                          notificationTime: TimeOfDay(
                            hour: _notificationTimeMinutes ~/ 60,
                            minute: _notificationTimeMinutes % 60,
                          ),
                          onEnable: _enableNotifications,
                          onChangeTime: _selectNotificationTime,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _RescueSummary(
                        rescueSoonCount: _rescueSoonCount,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Text(
                            'Expiring soon',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_visibleItems.length} items',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const SliverPadding(
                      padding: EdgeInsets.all(32),
                      sliver: SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (_loadError != null)
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverToBoxAdapter(
                        child: _LoadErrorState(
                          message: _loadError!,
                          onRetry: _loadItems,
                        ),
                      ),
                    )
                  else if (_visibleItems.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.all(24),
                      sliver: SliverToBoxAdapter(child: _EmptyFridgeState()),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: _visibleItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _visibleItems[index];
                          return _FridgeItemCard(
                            item: item,
                            onToggleConsumed: () => _toggleConsumed(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _generateRecipes,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _AiRecipeLab(
                    priorityCount: _recipePriorityCount,
                    availableCount: _activeIngredients.length,
                    isGenerating: _isGenerating,
                    recipes: _recipes,
                    errorMessage: _recipeError,
                    onGenerate: _generateRecipes,
                    onSelectRecipe: _openRecipe,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryNotificationBanner extends StatelessWidget {
  const _ExpiryNotificationBanner({
    required this.permission,
    required this.notificationTime,
    required this.onEnable,
    required this.onChangeTime,
  });

  final ExpiryNotificationPermission permission;
  final TimeOfDay notificationTime;
  final VoidCallback onEnable;
  final VoidCallback onChangeTime;

  @override
  Widget build(BuildContext context) {
    final isEnabled = permission == ExpiryNotificationPermission.granted;
    final isDenied = permission == ExpiryNotificationPermission.denied;
    final background = isEnabled
        ? const Color(0xFFE5F6E9)
        : isDenied
            ? const Color(0xFFFFF3D6)
            : const Color(0xFFF0ECFF);
    final foreground = isEnabled
        ? const Color(0xFF176B3A)
        : isDenied
            ? const Color(0xFF8A6100)
            : const Color(0xFF5F43C8);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEnabled
                    ? Icons.notifications_active_rounded
                    : isDenied
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_none_rounded,
                color: foreground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnabled
                          ? 'Expiry notifications are on'
                          : isDenied
                              ? 'Notifications are blocked'
                              : 'Get expiry reminders',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEnabled
                          ? 'We will alert you at your chosen time.'
                          : isDenied
                              ? 'Allow notifications in your browser settings.'
                              : 'Enable alerts for newly expiring fridge items.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onChangeTime,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(notificationTime.format(context)),
                style: OutlinedButton.styleFrom(foregroundColor: foreground),
              ),
              const Spacer(),
              if (!isEnabled && !isDenied)
                FilledButton.tonal(
                  onPressed: onEnable,
                  child: const Text('Enable'),
                )
              else if (isEnabled)
                TextButton(
                  onPressed: onChangeTime,
                  child: const Text('Change time'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RescueSummary extends StatelessWidget {
  const _RescueSummary({
    required this.rescueSoonCount,
  });

  final int rescueSoonCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF155E3B), Color(0xFF278A52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29155E3B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rescueSoonCount == 0
                      ? 'Your fridge is on track'
                      : '$rescueSoonCount items need rescuing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These foods are prioritized for your next meal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FridgeItemCard extends StatelessWidget {
  const _FridgeItemCard({
    required this.item,
    required this.onToggleConsumed,
  });

  final FridgeItem item;
  final VoidCallback onToggleConsumed;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = item.statusAt(now);
    final statusStyle = _statusStyle(item, status, now);
    final theme = Theme.of(context);

    return Material(
      color: item.isConsumed ? const Color(0xFFF0F1EE) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusStyle.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _categoryIcon(item.category),
                color: statusStyle.foreground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration:
                          item.isConsumed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatQuantity(item.quantity)} ${item.unit} · ${_categoryLabel(item.category)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusStyle.background,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _statusLabel(item, status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusStyle.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onToggleConsumed,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(item.isConsumed ? 'Undo' : 'I ate this'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatQuantity(double quantity) {
    return quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
  }

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'produce':
        return Icons.eco_outlined;
      case 'meat':
      case 'seafood':
        return Icons.egg_alt_outlined;
      case 'dairy':
      case 'beverage':
        return Icons.local_drink_outlined;
      case 'pantry':
        return Icons.rice_bowl_outlined;
      default:
        return Icons.kitchen_outlined;
    }
  }

  static String _statusLabel(FridgeItem item, FridgeItemStatus status) {
    switch (status) {
      case FridgeItemStatus.overdue:
        final days = item.daysRemainingAt(DateTime.now())!.abs();
        return '$days d overdue';
      case FridgeItemStatus.today:
        return 'Use today';
      case FridgeItemStatus.soon:
        return '${item.daysRemainingAt(DateTime.now())} d left';
      case FridgeItemStatus.fresh:
        return '${item.daysRemainingAt(DateTime.now())} d left';
      case FridgeItemStatus.noExpiry:
        return 'No expiry';
      case FridgeItemStatus.consumed:
        return 'Consumed';
    }
  }

  // Urgency coloring: 1 day (or less) left is red, 2 days left is yellow,
  // 3+ days left is green — the food category icon shares the same color.
  static const _red = _StatusStyle(Color(0xFFFFE5E2), Color(0xFFB42318));
  static const _yellow = _StatusStyle(Color(0xFFFFF3C6), Color(0xFF8A6100));
  static const _green = _StatusStyle(Color(0xFFE2F6E8), Color(0xFF176B3A));

  static _StatusStyle _statusStyle(
    FridgeItem item,
    FridgeItemStatus status,
    DateTime now,
  ) {
    switch (status) {
      case FridgeItemStatus.overdue:
        return _red;
      case FridgeItemStatus.noExpiry:
        return const _StatusStyle(Color(0xFFE7EEF5), Color(0xFF36566F));
      case FridgeItemStatus.consumed:
        return const _StatusStyle(Color(0xFFE6E8E3), Color(0xFF5F665D));
      case FridgeItemStatus.today:
      case FridgeItemStatus.soon:
      case FridgeItemStatus.fresh:
        final daysLeft = item.daysRemainingAt(now) ?? 99;
        if (daysLeft <= 1) return _red;
        if (daysLeft == 2) return _yellow;
        return _green;
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class _AiRecipeLab extends StatelessWidget {
  const _AiRecipeLab({
    required this.priorityCount,
    required this.availableCount,
    required this.isGenerating,
    required this.recipes,
    required this.errorMessage,
    required this.onGenerate,
    required this.onSelectRecipe,
  });

  final int priorityCount;
  final int availableCount;
  final bool isGenerating;
  final List<RecipeSuggestion> recipes;
  final String? errorMessage;
  final VoidCallback onGenerate;
  final ValueChanged<RecipeSuggestion> onSelectRecipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9D0FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D4DD4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rescue Recipes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$priorityCount expiring soon · $availableCount foods considered',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (recipes.isNotEmpty)
                IconButton(
                  tooltip: 'Refresh recipes',
                  onPressed: isGenerating ? null : onGenerate,
                  icon: isGenerating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'AI checks all available food and prioritizes ingredients that expire soon.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isGenerating && recipes.isEmpty) ...[
            const SizedBox(height: 24),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Preparing your rescue recipes…'),
                ],
              ),
            ),
          ],
          if (errorMessage != null && recipes.isEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ],
          if (recipes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Recommended for you',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...recipes.map(
              (recipe) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecipeCard(
                  recipe: recipe,
                  onSelect: () => onSelectRecipe(recipe),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onSelect});

  final RecipeSuggestion recipe;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: RecipeImage(
                    recipeTitle: recipe.title,
                    fallback: Container(
                      color: const Color(0xFFE9E2FF),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: Color(0xFF6D4DD4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${recipe.timeMinutes} min · ${recipe.difficulty} · ${recipe.servings} pax',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(recipe.summary),
          if (recipe.ingredientsUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recipe.ingredientsUsed
                  .take(3)
                  .map((ingredient) => Chip(label: Text(ingredient.name)))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onSelect,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Select recipe'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFridgeState extends StatelessWidget {
  const _EmptyFridgeState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 44),
          SizedBox(height: 8),
          Text('Nothing needs rescuing soon.'),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
