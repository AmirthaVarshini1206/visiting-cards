import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_db_service.dart';

final localDbServiceProvider = Provider((ref) => LocalDatabaseService());

class LocalCardsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final LocalDatabaseService _db;

  LocalCardsNotifier(this._db) : super(const AsyncValue.loading()) {
    loadCards();
  }

  Future<void> loadCards() async {
    try {
      final cards = await _db.getCards();
      
      // Sort by SL No descending by default so newest uploads show at the top
      cards.sort((a, b) {
        final slA = a['sl_no'] ?? a['SL No'] ?? 0;
        final slB = b['sl_no'] ?? b['SL No'] ?? 0;
        final intA = slA is int ? slA : int.tryParse(slA.toString()) ?? 0;
        final intB = slB is int ? slB : int.tryParse(slB.toString()) ?? 0;
        return intB.compareTo(intA);
      });

      state = AsyncValue.data(cards);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<int> addCard(Map<String, dynamic> card) async {
    final slNo = await _db.saveCard(card);
    await loadCards(); // Re-trigger reactive state update
    return slNo;
  }

  Future<void> deleteCard(int slNo) async {
    await _db.deleteCard(slNo);
    await loadCards(); // Re-trigger reactive state update
  }
}

// State notifier for managing local cards
final localCardsProvider = StateNotifierProvider<LocalCardsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final db = ref.watch(localDbServiceProvider);
  return LocalCardsNotifier(db);
});

// Backwards compatibility provider for V2 screens relying on sheetDataProvider
final sheetDataProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final localState = ref.watch(localCardsProvider);
  return localState.maybeWhen(
    data: (list) => list,
    orElse: () => <dynamic>[],
  );
});
