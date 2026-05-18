import '../../../core/network/api_client.dart';

class MessagesApi {
  MessagesApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> listConversations(String accessToken) {
    return _apiClient.getJsonList('/conversations', bearerToken: accessToken);
  }

  Future<List<dynamic>> listMessages({
    required String accessToken,
    required String conversationId,
  }) {
    return _apiClient.getJsonList(
      '/conversations/$conversationId/messages',
      bearerToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    required String accessToken,
    required String conversationId,
    required String body,
  }) {
    return _apiClient.postJson(
      '/conversations/$conversationId/messages',
      bearerToken: accessToken,
      body: <String, dynamic>{'body': body},
    );
  }

  Future<Map<String, dynamic>> startConversation({
    required String accessToken,
    required String otherUserId,
  }) {
    return _apiClient.postJson(
      '/conversations/start',
      bearerToken: accessToken,
      body: <String, dynamic>{'otherUserId': otherUserId},
    );
  }

  Future<Map<String, dynamic>> markConversationRead({
    required String accessToken,
    required String conversationId,
  }) {
    return _apiClient.patchJson(
      '/conversations/$conversationId/read',
      bearerToken: accessToken,
    );
  }
}
