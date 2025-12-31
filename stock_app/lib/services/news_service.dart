import 'dart:convert';
import 'package:http/http.dart' as http;

class NewsArticle {
  final String title;
  final String description;
  final String url;
  final String urlToImage;
  final String source;
  final DateTime publishedAt;

  NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    required this.urlToImage,
    required this.source,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? '',
      url: json['url'] ?? '',
      urlToImage: json['urlToImage'] ?? '',
      source: json['source']['name'] ?? 'Unknown',
      publishedAt: DateTime.parse(json['publishedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class NewsService {
  // Replace with your actual API keys
  static const String _newsApiKey = '81bbcea5bc914d8396119fbd0f2ef966'; 
  // static const String _stocktwitsApiKey = 'YOUR_STOCKTWITS_KEY'; // If needed

  Future<List<NewsArticle>> fetchMarketNews() async {
    // In a real app, you would use the API key to fetch data.
    // For demonstration purposes, we will return mock data if the key is not set or call fails.
    
    if (_newsApiKey == 'YOUR_NEWSAPI_KEY') {
      return _getMockNews();
    }

    try {
      final response = await http.get(
        Uri.parse('https://newsapi.org/v2/top-headlines?category=business&language=en&apiKey=$_newsApiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> articles = data['articles'];
        return articles.map((json) => NewsArticle.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load news');
      }
    } catch (e) {
      print('Error fetching news: $e');
      return _getMockNews();
    }
  }

  Future<List<NewsArticle>> _getMockNews() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    return [
      NewsArticle(
        title: 'Fed Signals Potential Rate Cuts in Late 2025',
        description: 'The Federal Reserve has indicated that inflation is cooling faster than expected, opening the door for interest rate cuts later this year.',
        url: 'https://example.com',
        urlToImage: 'https://images.unsplash.com/photo-1611974765270-ca1258634369?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
        source: 'Financial Times',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NewsArticle(
        title: 'Tech Stocks Rally as AI Demand Surges',
        description: 'Major tech companies see stock prices soar as demand for artificial intelligence chips and software continues to outpace supply.',
        url: 'https://example.com',
        urlToImage: 'https://images.unsplash.com/photo-1518186285589-2f7649de83e0?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
        source: 'Bloomberg',
        publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      NewsArticle(
        title: 'Oil Prices Stabilize Amid Geopolitical Tensions',
        description: 'Crude oil prices have found a floor after weeks of volatility, as traders assess the impact of ongoing conflicts in the Middle East.',
        url: 'https://example.com',
        urlToImage: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
        source: 'Reuters',
        publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      NewsArticle(
        title: 'Crypto Market Update: Bitcoin Reclaims \$45k',
        description: 'Bitcoin has surged past the \$45,000 mark, driven by renewed institutional interest and positive regulatory news.',
        url: 'https://example.com',
        urlToImage: 'https://images.unsplash.com/photo-1518546305927-5a555bb7020d?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
        source: 'CoinDesk',
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      NewsArticle(
        title: 'Electric Vehicle Sales Hit Record Highs',
        description: 'Global sales of electric vehicles reached a new milestone last quarter, with China and Europe leading the charge.',
        url: 'https://example.com',
        urlToImage: 'https://images.unsplash.com/photo-1593941707882-a5bba14938c7?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
        source: 'CNBC',
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
