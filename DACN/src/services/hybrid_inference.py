import torch
import joblib
import pandas as pd
import numpy as np
from pathlib import Path
import sys
import os
import datetime
import joblib
import pandas as pd
import numpy as np
from pathlib import Path
import sys
import os

# Add project root to path
sys.path.append(os.getcwd())

from src.models.hybrid_model import LSTMFeatureExtractor

MODEL_DIR = Path("models/hybrid")
DATA_DIR = Path("data")
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
SENTIMENT_FILE = PROCESSED_DIR / "sentiment_mined.csv"

# Model Config (Should match training)
SEQ_LEN = 10
HIDDEN_DIM = 32
NUM_LAYERS = 2

class HybridInferenceService:
    def __init__(self, ticker):
        self.ticker = ticker
        self.ticker_dir = MODEL_DIR / ticker
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        
        self.load_models()
        
    def load_models(self):
        if not self.ticker_dir.exists():
            raise FileNotFoundError(f"Models for {self.ticker} not found in {self.ticker_dir}")
            
        # Load Scaler
        self.scaler = joblib.load(self.ticker_dir / "scaler.pkl")
        
        # Load XGBoost
        self.xgb_model = joblib.load(self.ticker_dir / "xgb.pkl")
        
        # Load LSTM
        # We need to know input dim from scaler (n_features)
        input_dim = self.scaler.n_features_in_
        self.lstm_model = LSTMFeatureExtractor(input_dim, HIDDEN_DIM, NUM_LAYERS, 1).to(self.device)
        self.lstm_model.load_state_dict(torch.load(self.ticker_dir / "lstm.pth", map_location=self.device))
        self.lstm_model.eval()
        
    def get_latest_data(self, df_input=None):
        # Load full history + sentiment to construct the latest sequence
        # In production, this would fetch from DB or API
        
        if df_input is not None:
            df = df_input.copy()
            # Ensure required columns exist
            required_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
            if not all(col in df.columns for col in required_cols):
                 raise ValueError(f"Input DataFrame missing required columns: {required_cols}")
            
            # If sentiment columns missing, fill with 0
            for col in ['sentiment_mean', 'sentiment_std', 'news_count']:
                if col not in df.columns:
                    df[col] = 0
            
            # Ensure Date column exists and is datetime
            if 'Date' not in df.columns:
                 # If no Date column, assume index is Date or create dummy
                 df['Date'] = pd.Timestamp.now()
            else:
                 df['Date'] = pd.to_datetime(df['Date'], utc=True).dt.normalize()

        else:
            stock_path = RAW_DIR / f"{self.ticker}_full.csv"
            if not stock_path.exists():
                 raise FileNotFoundError(f"Data file not found: {stock_path}")
                 
            df_stock = pd.read_csv(stock_path)
            df_stock['Date'] = pd.to_datetime(df_stock['Date'], utc=True).dt.normalize()
            df_stock = df_stock.sort_values('Date')
            
            if SENTIMENT_FILE.exists():
                df_sent = pd.read_csv(SENTIMENT_FILE)
                df_sent['date'] = pd.to_datetime(df_sent['date'], utc=True).dt.normalize()
                df_sent = df_sent[df_sent['ticker'] == self.ticker].copy()
                df = pd.merge(df_stock, df_sent, left_on='Date', right_on='date', how='left')
                df = df.drop(columns=['date', 'ticker'])
                df[['sentiment_mean', 'sentiment_std', 'news_count']] = df[['sentiment_mean', 'sentiment_std', 'news_count']].fillna(0)
            else:
                # Fallback if no sentiment file
                df = df_stock
                df['sentiment_mean'] = 0
                df['sentiment_std'] = 0
                df['news_count'] = 0
            
        # Feature selection (must match training)
        feature_cols = ['Open', 'High', 'Low', 'Close', 'Volume', 'sentiment_mean', 'sentiment_std', 'news_count']
        
        # Get last SEQ_LEN rows
        if len(df) < SEQ_LEN:
             # Pad with first row if not enough data, or raise error
             # For robustness, let's pad if we have at least 1 row
             if len(df) > 0:
                 padding = pd.DataFrame([df.iloc[0]] * (SEQ_LEN - len(df)), columns=df.columns)
                 df = pd.concat([padding, df], ignore_index=True)
             else:
                raise ValueError("Not enough data for inference")
            
        last_seq = df[feature_cols].iloc[-SEQ_LEN:].values
        last_date = df['Date'].iloc[-1]
        
        return last_seq, last_date
        
    def predict(self, df_input=None):
        try:
            raw_seq, date = self.get_latest_data(df_input)
        except Exception as e:
            print(f"Error getting data for {self.ticker}: {e}")
            return {"action": "HOLD", "confidence": 0.0, "date": str(datetime.date.today())}
            
        # Scale
        seq_scaled = self.scaler.transform(raw_seq)
        
        # LSTM Feature Extraction
        seq_tensor = torch.FloatTensor(seq_scaled).unsqueeze(0).to(self.device) # (1, seq_len, input_dim)
        
        with torch.no_grad():
            _, lstm_features = self.lstm_model(seq_tensor)
            
        lstm_features = lstm_features.cpu().numpy()
        
        # Combine with last step sentiment
        # Sentiment indices: 5, 6, 7
        last_sent = seq_scaled[-1, 5:].reshape(1, -1)
        
        final_features = np.hstack([lstm_features, last_sent])
        
        # XGBoost Prediction
        prob = self.xgb_model.predict_proba(final_features)[0][1] # Prob of class 1 (Up)
        pred = self.xgb_model.predict(final_features)[0]
        
        action = "BUY" if pred == 1 else "SELL" # Or HOLD if prob is weak?
        
        # Simple threshold logic
        if prob > 0.6:
            action = "BUY"
        elif prob < 0.4:
            action = "SELL"
        else:
            action = "HOLD"
            
        return {
            "ticker": self.ticker,
            "date": str(date.date()) if hasattr(date, 'date') else str(date),
            "action": action,
            "confidence": float(prob),
            "model": "Hybrid_XGB_LSTM"
        }


