import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/prediction_entity.dart';
import '../presentation/providers/prediction_provider.dart';
import '../theme/app_colors.dart';

class AiPredictionCard extends ConsumerStatefulWidget {
  final String symbol;

  const AiPredictionCard({super.key, required this.symbol});

  @override
  ConsumerState<AiPredictionCard> createState() => _AiPredictionCardState();
}

class _AiPredictionCardState extends ConsumerState<AiPredictionCard> {
  
  @override
  Widget build(BuildContext context) {
    // Watch Prediction for this symbol
    // predictionControllerProvider is a family provider
    final predictionAsync = ref.watch(predictionControllerProvider(widget.symbol));
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text(
                  'AI Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.smart_toy, color: AppColors.primary),
               ],
             ),
            const SizedBox(height: 16),
            predictionAsync.when(
              data: (prediction) {
                if (prediction == null) {
                  return const Text("No prediction available.");
                }
                return _buildPredictionContent(prediction);
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, st) => Text("Unavailable: $e", style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionContent(PredictionEntity prediction) {
     final color = _getActionColor(prediction.action);
     
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                prediction.action.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: color.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(8)
                 ),
                 child: Text(
                   'Confidence: ${prediction.confidence}%',
                   style: TextStyle(fontWeight: FontWeight.bold, color: color),
                 ),
              )
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: prediction.confidence / 100, 
            backgroundColor: Colors.grey[200],
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            prediction.rationale,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 8),
       ],
     );
  }

  Color _getActionColor(PredictionAction action) {
    switch (action) {
      case PredictionAction.buy: return AppColors.success;
      case PredictionAction.sell: return AppColors.danger;
      case PredictionAction.hold: return Colors.orange;
    }
  }
}

