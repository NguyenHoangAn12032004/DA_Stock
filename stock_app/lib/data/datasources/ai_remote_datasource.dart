import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/errors/failures.dart';

abstract class AiRemoteDataSource {
  Future<String> chat(String symbol, String message);
  // We can reuse chat endpoint for portfolio analysis by constructing a specific prompt
  Future<String> analyzePortfolio(String contextPrompt);
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  final http.Client client;
  // TODO: Move base URLs to AppConstants
  static const String aiBaseUrl = 'http://10.0.2.2:8001'; 

  AiRemoteDataSourceImpl({required this.client});

  @override
  Future<String> chat(String symbol, String message) async {
    final url = Uri.parse('$aiBaseUrl/chat');
    try {
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'symbol': symbol,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? 'No reply';
      } else {
        throw ServerFailure('AI Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> analyzePortfolio(String contextPrompt) async {
    // Use "AAPL" as a proxy for General Market Context. 
    // Sending "PORTFOLIO" causes the backend to try (and fail) to fetch stock data for distinct symbol "PORTFOLIO".
    return chat("AAPL", contextPrompt);
  }
}
