import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;
import '../../data/datasources/ai_remote_datasource.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../domain/repositories/ai_repository.dart';
import 'portfolio_provider.dart';

part 'chat_provider.g.dart';

// --- Dependencies ---

@riverpod
AiRemoteDataSource aiRemoteDataSource(AiRemoteDataSourceRef ref) {
  return AiRemoteDataSourceImpl(client: http.Client());
}

@riverpod
AiRepository aiRepository(AiRepositoryRef ref) {
  return AiRepositoryImpl(ref.watch(aiRemoteDataSourceProvider));
}

// --- State ---

class ChatMessage {
  final String role; // 'user' or 'bot'
  final String message;
  final String type; // 'text', 'error', 'analysis'

  ChatMessage({required this.role, required this.message, this.type = 'text'});
}

@riverpod
class ChatController extends _$ChatController {
  @override
  List<ChatMessage> build() {
    return [
      ChatMessage(
        role: 'bot',
        message: 'Hello! I\'m your Gemini Investment Assistant. I can help you understand market trends or analyze your portfolio.',
      )
    ];
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add User Message
    final userMsg = ChatMessage(role: 'user', message: text);
    state = [...state, userMsg];

    // Detect context (simple)
    String symbol = "AAPL";
    if (text.toUpperCase().contains("HPG")) symbol = "HPG";
    if (text.toUpperCase().contains("FPT")) symbol = "FPT";

    // Call API
    final repo = ref.read(aiRepositoryProvider);
    final result = await repo.sendMessage(symbol, text);

    result.fold(
      (failure) {
        state = [...state, ChatMessage(role: 'bot', message: "Error: ${failure.message}", type: 'error')];
      },
      (reply) {
        state = [...state, ChatMessage(role: 'bot', message: reply)];
      },
    );
  }

  Future<void> analyzePortfolio() async {
    // Add "System" Message to show valid request
    state = [...state, ChatMessage(role: 'user', message: "Analyze my portfolio status.", type: 'text')];

    // Get Portfolio State
    final portfolioState = await ref.read(portfolioControllerProvider.future);
    final portfolio = portfolioState.portfolio;

    if (portfolio == null) {
       state = [...state, ChatMessage(role: 'bot', message: "Please log in and ensure you have a portfolio.", type: 'error')];
       return;
    }

    final repo = ref.read(aiRepositoryProvider);
    final result = await repo.analyzePortfolio(
      portfolio, 
      portfolioState.totalEquity, 
      portfolioState.cashBalance
    );

    result.fold(
      (failure) {
        state = [...state, ChatMessage(role: 'bot', message: "Analysis Failed: ${failure.message}", type: 'error')];
      },
      (reply) {
        state = [...state, ChatMessage(role: 'bot', message: reply, type: 'text')];
      },
    );
  }
}
