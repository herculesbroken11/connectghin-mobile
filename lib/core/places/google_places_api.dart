import 'dart:convert';

import 'package:http/http.dart' as http;

/// Classic Places API (autocomplete + details). Requires **Places API** enabled on the key.
class GooglePlacesApi {
  GooglePlacesApi(this._apiKey);

  final String _apiKey;

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    final q = input.trim();
    if (q.length < 3) return const [];

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', <String, String>{
      'input': q,
      'key': _apiKey,
      'types': 'address',
      'language': 'en',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw GooglePlacesException('Address search failed (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _throwIfPlacesError(json, fallback: 'Address search failed.');
    final preds = json['predictions'] as List<dynamic>? ?? const <dynamic>[];
    return preds
        .map((e) => e as Map<String, dynamic>)
        .map(
          (e) => PlaceSuggestion(
            placeId: e['place_id'] as String? ?? '',
            description: e['description'] as String? ?? '',
          ),
        )
        .where((e) => e.placeId.isNotEmpty && e.description.isNotEmpty)
        .take(6)
        .toList();
  }

  Future<Map<String, dynamic>> placeDetails(String placeId) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', <String, String>{
      'place_id': placeId,
      'key': _apiKey,
      'fields': 'address_component,formatted_address,geometry',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw GooglePlacesException('Could not load address details (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _throwIfPlacesError(json, fallback: 'Could not load address details.');
    return json['result'] as Map<String, dynamic>? ?? const <String, dynamic>{};
  }

  void _throwIfPlacesError(Map<String, dynamic> json, {required String fallback}) {
    final status = json['status'] as String? ?? '';
    if (status == 'OK' || status == 'ZERO_RESULTS') return;
    final msg = json['error_message'] as String?;
    throw GooglePlacesException(_statusMessage(status, msg) ?? fallback);
  }

  static String? _statusMessage(String status, String? apiMessage) {
    if (apiMessage != null && apiMessage.trim().isNotEmpty) return apiMessage.trim();
    return switch (status) {
      'REQUEST_DENIED' =>
        'Places API key was denied. Enable Places API and check key restrictions in Google Cloud.',
      'INVALID_REQUEST' => 'Invalid address search request.',
      'OVER_QUERY_LIMIT' => 'Places API quota exceeded. Try again later.',
      _ => status.isNotEmpty ? 'Places API error: $status' : null,
    };
  }
}

class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});

  final String placeId;
  final String description;
}

class GooglePlacesException implements Exception {
  GooglePlacesException(this.message);

  final String message;

  @override
  String toString() => message;
}
