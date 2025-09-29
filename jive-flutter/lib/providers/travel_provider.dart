import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/travel_event.dart';
import 'package:jive_money/services/api/travel_service.dart';
import 'package:jive_money/providers/api_service_provider.dart';

// Travel service provider
final travelServiceProvider = Provider<TravelService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return TravelService(apiService);
});

// Travel events state provider
final travelEventsProvider = StateNotifierProvider<TravelEventsNotifier, AsyncValue<List<TravelEvent>>>((ref) {
  final service = ref.watch(travelServiceProvider);
  return TravelEventsNotifier(service);
});

// Travel events notifier
class TravelEventsNotifier extends StateNotifier<AsyncValue<List<TravelEvent>>> {
  final TravelService _service;

  TravelEventsNotifier(this._service) : super(const AsyncValue.loading()) {
    loadEvents();
  }

  Future<void> loadEvents() async {
    state = const AsyncValue.loading();
    try {
      final events = await _service.getEvents();
      state = AsyncValue.data(events);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> addEvent(TravelEvent event) async {
    try {
      await _service.createEvent(event);
      await loadEvents();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> updateEvent(TravelEvent event) async {
    try {
      await _service.updateEvent(event.id, event);
      await loadEvents();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _service.deleteEvent(eventId);
      await loadEvents();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}

// Travel provider for compatibility with router
class TravelProvider {
  final TravelService service;

  TravelProvider({required this.service});
}