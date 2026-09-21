import 'package:destiny/models/destina_chat.dart';
import 'package:destiny/services/destina_api_client.dart';

class DestinaRepository {
  DestinaRepository({DestinaApiClient? client})
      : _client = client ?? DestinaApiClient();

  final DestinaApiClient _client;

  Future<DestinaTurn> send({
    required String message,
    String? conversationId,
    Map<String, dynamic>? seedContext,
  }) {
    return _client.chat(
      message: message,
      conversationId: conversationId,
      seedContext: seedContext,
    );
  }
}
