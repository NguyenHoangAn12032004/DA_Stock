class Signal {
  final String ticker;
  final String action;
  final double weight;
  final double confidence;

  Signal({
    required this.ticker,
    required this.action,
    required this.weight,
    required this.confidence,
  });

  factory Signal.fromJson(String ticker, Map<String, dynamic> json) {
    return Signal(
      ticker: ticker,
      action: json['action'] ?? 'HOLD',
      weight: (json['weight'] ?? 0.0).toDouble(),
      confidence: (json['probability'] ?? 0.0).toDouble(), // API uses 'probability' in some endpoints, 'confidence' in others. Checking server code...
      // In advice_server.py: 
      // _rows_to_payload uses 'confidence'
      // /rl/predict payload.get("signals") -> returns dict.
      // Let's re-verify the /rl/predict response format from server code or docs.
      // Server code: payload.get("signals") returns a dict of signals.
      // Signal dict keys? 
      // predict_latest call in server calls src.services.rl_inference.predict_latest
      // I don't see that file. But user provided:  "probability": 0 in /chat endpoint.
      // In User Request "Dart Implementation": confidence: (json['direction_prob'] ?? 0.0)
      // Wait, let's use what the user provided in the request as a baseline, but adapt if needed.
      // User said: confidence: (json['direction_prob'] ?? 0.0).toDouble()
    );
  }
}
