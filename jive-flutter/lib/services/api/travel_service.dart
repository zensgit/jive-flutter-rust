import 'package:dio/dio.dart';
import 'package:jive_money/services/api_service.dart';
import 'package:jive_money/models/travel_event.dart';
import 'package:jive_money/core/network/http_client.dart';

class TravelService {
  final ApiService _apiService;

  TravelService(this._apiService);

  // Get all travel events
  Future<List<TravelEvent>> getEvents() async {
    try {
      final response = await _apiService.dio.get('/api/v1/travel/events');
      return (response.data as List)
          .map((json) => TravelEvent.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load travel events: $e');
    }
  }

  // Get a single travel event
  Future<TravelEvent> getEvent(String id) async {
    try {
      final response = await _apiService.dio.get('/api/v1/travel/events/$id');
      return TravelEvent.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load travel event: $e');
    }
  }

  // Create a new travel event
  Future<TravelEvent> createEvent(TravelEvent event) async {
    try {
      final response = await _apiService.dio.post(
        '/api/v1/travel/events',
        data: event.toJson(),
      );
      return TravelEvent.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create travel event: $e');
    }
  }

  // Update an existing travel event
  Future<TravelEvent> updateEvent(String id, TravelEvent event) async {
    try {
      final response = await _apiService.dio.put(
        '/api/v1/travel/events/$id',
        data: event.toJson(),
      );
      return TravelEvent.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update travel event: $e');
    }
  }

  // Delete a travel event
  Future<void> deleteEvent(String id) async {
    try {
      await _apiService.dio.delete('/api/v1/travel/events/$id');
    } catch (e) {
      throw Exception('Failed to delete travel event: $e');
    }
  }

  // Link transaction to travel event
  Future<void> linkTransaction(String eventId, String transactionId) async {
    try {
      await _apiService.dio.post(
        '/api/v1/travel/events/$eventId/transactions',
        data: {'transaction_id': transactionId},
      );
    } catch (e) {
      throw Exception('Failed to link transaction: $e');
    }
  }

  // Unlink transaction from travel event
  Future<void> unlinkTransaction(String eventId, String transactionId) async {
    try {
      await _apiService.dio.delete(
        '/api/v1/travel/events/$eventId/transactions/$transactionId',
      );
    } catch (e) {
      throw Exception('Failed to unlink transaction: $e');
    }
  }
}

// Extension to add dio getter to ApiService if not present
extension ApiServiceExt on ApiService {
  Dio get dio => HttpClient.instance.dio;
}