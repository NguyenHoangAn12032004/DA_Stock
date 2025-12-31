import torch
from transformers import pipeline
import numpy as np
from typing import List, Union

class FinBERTService:
    def __init__(self, model_name="ProsusAI/finbert", device=None):
        """
        Initialize the FinBERT sentiment analysis pipeline.
        Args:
            model_name (str): The Hugging Face model identifier.
            device (int): Device index to use (e.g., 0 for GPU, -1 for CPU). 
                          If None, auto-detects.
        """
        if device is None:
            device = 0 if torch.cuda.is_available() else -1
        
        print(f"Loading FinBERT model: {model_name} on device {device}...")
        self.pipe = pipeline("sentiment-analysis", model=model_name, device=device, truncating=True, max_length=512)
        print("FinBERT loaded successfully.")

    def analyze_sentiment(self, texts: Union[str, List[str]]) -> np.ndarray:
        """
        Analyze sentiment for a list of texts or a single string.
        Returns:
            np.ndarray: Array of sentiment scores [-1, 1].
                        Positive=1, Neutral=0, Negative=-1 (approx).
                        Actually, FinBERT output labels are 'positive', 'neutral', 'negative'.
                        We will map: positive -> 1.0, neutral -> 0.0, negative -> -1.0
                        Weighted by confidence score? 
                        Let's output the weighted score: 
                        score = confidence * label_sign
        """
        if isinstance(texts, str):
            texts = [texts]
        
        # Batch processing happens inside pipeline for lists, but explicit chunks can be safer for massive lists
        results = self.pipe(texts)
        
        scores = []
        for i, res in enumerate(results):
            label = res['label'].lower()
            score = res['score']
            
            val = 0.0
            if label == 'positive':
                val = score
            elif label == 'negative':
                val = -score
            else: # neutral
                val = 0.0 # Neutral has 0 directional impact, or usually implies 0.
            
            scores.append(val)
            
        return np.array(scores)

if __name__ == "__main__":
    # Test
    service = FinBERTService()
    samples = [
        "Apple reports record breaking earnings.",
        "Inflation fears rise as market tumbles.",
        "The company announced a new ceo."
    ]
    print(service.analyze_sentiment(samples))
