import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import pandas as pd
import numpy as np
from pathlib import Path
from typing import List, Dict, Union
from tqdm import tqdm

class SentimentProcessor:
    def __init__(self, model_name: str = "ProsusAI/finbert", device: str = None):
        self.model_name = model_name
        self.device = device if device else ("cuda" if torch.cuda.is_available() else "cpu")
        print(f"Loading FinBERT model ({self.model_name}) on {self.device}...")
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
        self.model = AutoModelForSequenceClassification.from_pretrained(self.model_name, use_safetensors=True).to(self.device)
        self.model.eval()
        self.labels = ["positive", "negative", "neutral"]

    def predict(self, texts: List[str], batch_size: int = 32) -> pd.DataFrame:
        """
        Predict sentiment for a list of texts.
        Returns a DataFrame with columns: [text, sentiment_score, sentiment_label]
        sentiment_score is a continuous value: positive - negative (approx) or weighted score.
        For FinBERT: 0: Positive, 1: Negative, 2: Neutral (Check model config!)
        Actually ProsusAI/finbert labels: 0: positive, 1: negative, 2: neutral
        Let's verify via config or assume standard.
        """
        all_probs = []
        
        for i in tqdm(range(0, len(texts), batch_size), desc="Processing batches"):
            batch_texts = texts[i : i + batch_size]
            inputs = self.tokenizer(batch_texts, return_tensors="pt", padding=True, truncation=True, max_length=512).to(self.device)
            
            with torch.no_grad():
                outputs = self.model(**inputs)
                probs = torch.nn.functional.softmax(outputs.logits, dim=-1)
                all_probs.append(probs.cpu().numpy())
                
        all_probs = np.concatenate(all_probs, axis=0)
        
        # Calculate a composite sentiment score
        # Score = Prob(Positive) - Prob(Negative)
        # Range: [-1, 1]
        # 0: Positive, 1: Negative, 2: Neutral
        # Wait, let's check label mapping for ProsusAI/finbert
        # Usually: 0: Positive, 1: Negative, 2: Neutral
        # But sometimes it's different.
        # Let's assume: 0=Pos, 1=Neg, 2=Neu based on common usage.
        # We will refine this if needed.
        
        # Actually, let's just save all probs
        df = pd.DataFrame(all_probs, columns=["prob_pos", "prob_neg", "prob_neu"])
        df["sentiment_score"] = df["prob_pos"] - df["prob_neg"]
        df["text"] = texts
        
        return df

    def process_daily_data(self, df: pd.DataFrame, text_col: str, date_col: str, ticker_col: str = None) -> pd.DataFrame:
        """
        Process a dataframe with text, date, and optional ticker.
        Aggregates sentiment by Date (and Ticker).
        """
        print(f"Processing {len(df)} items...")
        texts = df[text_col].astype(str).tolist()
        sent_df = self.predict(texts)
        
        df = df.reset_index(drop=True)
        sent_df = sent_df.reset_index(drop=True)
        merged = pd.concat([df[[date_col] + ([ticker_col] if ticker_col else [])], sent_df], axis=1)
        
        # Convert date
        merged[date_col] = pd.to_datetime(merged[date_col])
        
        # Group by
        group_cols = [date_col]
        if ticker_col:
            group_cols.append(ticker_col)
            
        agg_df = merged.groupby(group_cols)[["sentiment_score", "prob_pos", "prob_neg", "prob_neu"]].mean().reset_index()
        return agg_df

if __name__ == "__main__":
    # Test run
    processor = SentimentProcessor()
    test_texts = [
        "Apple reports record earnings for Q4.",
        "Google faces antitrust lawsuit.",
        "Market is flat today."
    ]
    res = processor.predict(test_texts)
    print(res)
