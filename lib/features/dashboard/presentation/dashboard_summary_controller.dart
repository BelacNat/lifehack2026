import 'package:flutter/foundation.dart';

/// Lets other features (e.g. the Fridge's daily-streak bump) ask the
/// Dashboard to re-fetch its summary, since it's normally only fetched
/// once in initState and the Dashboard branch stays alive in the
/// background between tab switches.
class DashboardSummaryController {
  DashboardSummaryController._();

  static final ValueNotifier<int> refreshTrigger = ValueNotifier<int>(0);

  static void requestRefresh() => refreshTrigger.value++;
}
